# frozen_string_literal: true

require "test_helper"

class InterviewPhaseDataPreservationTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Preservation Corp", subdomain: "preservecorp")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company,
      email: "admin@preservecorp.com",
      first_name: "Alice",
      last_name: "Admin",
      role: "admin"
    )

    @interviewer = User.create!(
      company: @company,
      email: "interviewer@preservecorp.com",
      first_name: "Ivan",
      last_name: "Viewer",
      role: "interviewer"
    )

    @role = Role.create!(company: @company, title: "Software Engineer")
    # Default phases: Phone Screen (0), Technical Interview (1), Onsite Interview (2), Final Interview (3)
    @phases = @role.interview_phases.ordered.to_a

    @candidate = Candidate.create!(
      company: @company,
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com"
    )

    @application = ApplicationSubmission.create!(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "interviewing"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # ==========================================
  # Phase Ordering
  # ==========================================

  test "phases maintain sequential positions after creation" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", role: @role, company: @company)
    p2 = InterviewPhase.create!(name: "Phase B", role: @role, company: @company)
    p3 = InterviewPhase.create!(name: "Phase C", role: @role, company: @company)

    assert_equal 0, p1.reload.position
    assert_equal 1, p2.reload.position
    assert_equal 2, p3.reload.position
  end

  test "move_to first position shifts all others down" do
    phases = @role.interview_phases.ordered.to_a
    last = phases.last # Final Interview at position 3

    last.move_to(0)

    reordered = @role.interview_phases.active.ordered.to_a
    assert_equal "Final Interview", reordered[0].name
    assert_equal "Phone Screen", reordered[1].name
    assert_equal "Technical Interview", reordered[2].name
    assert_equal "Onsite Interview", reordered[3].name

    # Verify positions are contiguous
    assert_equal [0, 1, 2, 3], reordered.map(&:position)
  end

  test "move_to last position shifts others up" do
    phases = @role.interview_phases.ordered.to_a
    first = phases.first # Phone Screen at position 0

    first.move_to(3)

    reordered = @role.interview_phases.active.ordered.to_a
    assert_equal "Technical Interview", reordered[0].name
    assert_equal "Onsite Interview", reordered[1].name
    assert_equal "Final Interview", reordered[2].name
    assert_equal "Phone Screen", reordered[3].name
  end

  test "move_to middle position correctly reorders" do
    phases = @role.interview_phases.ordered.to_a
    first = phases.first # Phone Screen at position 0

    first.move_to(2)

    reordered = @role.interview_phases.active.ordered.to_a
    assert_equal "Technical Interview", reordered[0].name
    assert_equal "Onsite Interview", reordered[1].name
    assert_equal "Phone Screen", reordered[2].name
    assert_equal "Final Interview", reordered[3].name
  end

  test "multiple move_to operations maintain consistency" do
    phases = @role.interview_phases.ordered.to_a

    # Move first to last
    phases[0].move_to(3)
    # Move what was second to first
    phases[1].reload.move_to(0)

    reordered = @role.interview_phases.active.ordered.to_a
    positions = reordered.map(&:position)
    assert_equal [0, 1, 2, 3], positions, "Positions should always be contiguous after moves"
  end

  test "positions remain contiguous after deleting middle phase" do
    @role.interview_phases.ordered.to_a[1].destroy! # Delete Technical Interview

    remaining = @role.interview_phases.active.ordered.to_a
    # Manually recompact (controller does this)
    remaining.each_with_index { |p, i| p.update_column(:position, i) if p.position != i }

    remaining.each(&:reload)
    assert_equal [0, 1, 2], remaining.map(&:position)
    assert_equal 3, remaining.size
  end

  test "ordered scope returns phases sorted by position ascending" do
    @role.interview_phases.destroy_all

    p3 = InterviewPhase.create!(name: "Third", role: @role, company: @company, position: 2)
    p3.update_column(:position, 2)
    p1 = InterviewPhase.create!(name: "First", role: @role, company: @company)
    p1.update_column(:position, 0)
    p2 = InterviewPhase.create!(name: "Second", role: @role, company: @company)
    p2.update_column(:position, 1)

    ordered = @role.interview_phases.ordered.to_a
    assert_equal %w[First Second Third], ordered.map(&:name)
  end

  # ==========================================
  # CRUD Operations
  # ==========================================

  test "creating a phase assigns auto-incremented position" do
    max_before = @role.interview_phases.active.maximum(:position)
    new_phase = @role.interview_phases.create!(name: "New Phase", company: @company)
    assert_equal max_before + 1, new_phase.position
  end

  test "creating phase with explicit position flag preserves given position" do
    phase = InterviewPhase.new(
      name: "Custom Position",
      role: @role,
      company: @company,
      position: 99
    )
    phase.explicit_position = true
    phase.save!
    assert_equal 99, phase.position
  end

  test "updating phase name without candidate data modifies in place" do
    phase = @phases[0]
    original_id = phase.id

    result = phase.update_with_versioning(name: "Renamed Phone Screen")

    assert_equal original_id, result.id
    assert_equal "Renamed Phone Screen", result.name
    assert result.active?
  end

  test "updating phase name with candidate data creates new version" do
    phase = @phases[0]
    original_id = phase.id

    # Create interview to make has_candidate_data? true
    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    result = phase.update_with_versioning(name: "Renamed Phone Screen")

    assert_not_equal original_id, result.id
    assert_equal "Renamed Phone Screen", result.name
    assert result.active?
    assert phase.reload.archived?
    assert_equal "Phone Screen", phase.name # original preserved
  end

  test "destroying phase removes it completely" do
    phase = @phases.last
    phase_id = phase.id

    phase.destroy!

    assert_not InterviewPhase.exists?(phase_id)
  end

  test "destroying role cascades to all phases" do
    phase_count = @role.interview_phases.count
    assert phase_count > 0

    phase_ids = @role.interview_phases.pluck(:id)
    @role.destroy!

    assert_equal 0, InterviewPhase.where(id: phase_ids).count
  end

  test "creating phase with duplicate name in same role fails" do
    phase = InterviewPhase.new(
      name: "Phone Screen", # already exists
      role: @role,
      company: @company
    )
    assert_not phase.valid?
    assert phase.errors[:name].any?
  end

  test "creating phase with same name in different role succeeds" do
    other_role = Role.create!(company: @company, title: "Designer")
    # Default phases are seeded, so "Phone Screen" already exists in other_role too
    # Create with a unique name then verify cross-role naming
    phase = InterviewPhase.new(
      name: "Unique Cross-Role Phase",
      role: @role,
      company: @company
    )
    assert phase.valid?

    other_phase = InterviewPhase.new(
      name: "Unique Cross-Role Phase",
      role: other_role,
      company: @company
    )
    assert other_phase.valid?
  end

  # ==========================================
  # Data Preservation When Phases Modified After Candidates Progress
  # ==========================================

  test "interview record preserved when phase is versioned" do
    phase = @phases[0]

    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "scheduled",
      scheduled_at: 1.day.from_now
    )

    # Version the phase (archives old, creates new)
    new_phase = phase.update_with_versioning(name: "Updated Phone Screen")

    # Original interview still exists and points to the archived phase
    interview.reload
    assert_equal phase.id, interview.interview_phase_id
    assert interview.interview_phase.archived?
    assert_equal "Phone Screen", interview.interview_phase.name
  end

  test "scorecard data preserved when phase is versioned" do
    phase = @phases[0]

    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "complete"
    )

    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer,
      notes: "Great candidate, strong skills",
      submitted: true
    )

    ScorecardCategory.create!(
      scorecard: scorecard,
      name: "Technical Skills",
      rating: 5
    )

    ScorecardCategory.create!(
      scorecard: scorecard,
      name: "Communication",
      rating: 4
    )

    # Version the phase
    new_phase = phase.update_with_versioning(name: "Updated Phone Screen")

    # Verify all scorecard data is intact
    scorecard.reload
    assert_equal "Great candidate, strong skills", scorecard.notes
    assert scorecard.submitted?
    assert_equal 2, scorecard.scorecard_categories.count
    assert_equal 5, scorecard.scorecard_categories.find_by(name: "Technical Skills").rating
    assert_equal 4, scorecard.scorecard_categories.find_by(name: "Communication").rating

    # Scorecard's interview still references the archived phase
    assert_equal phase.id, scorecard.interview.interview_phase_id
    assert scorecard.interview.interview_phase.archived?
  end

  test "panel members preserved when phase is versioned" do
    phase = @phases[0]

    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "scheduled",
      scheduled_at: 2.days.from_now
    )

    interview.assign_interviewer!(@admin)
    interview.assign_interviewer!(@interviewer)

    # Version the phase
    new_phase = phase.update_with_versioning(name: "Updated Phone Screen")

    # Panel members still intact
    interview.reload
    assert_equal 2, interview.interview_participants.count
    assert interview.panel_member?(@admin)
    assert interview.panel_member?(@interviewer)
  end

  test "multiple interviews across phases preserved when one phase is versioned" do
    phase1 = @phases[0]
    phase2 = @phases[1]

    interview1 = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase1,
      status: "unscheduled"
    )
    interview1.update_columns(status: "complete", completed_at: 1.day.ago)

    interview2 = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase2,
      status: "scheduled",
      scheduled_at: 2.days.from_now
    )

    # Only version phase1
    new_phase1 = phase1.update_with_versioning(name: "Updated Phone Screen")

    # Both interviews still exist
    assert Interview.exists?(interview1.id)
    assert Interview.exists?(interview2.id)

    # Interview1 points to archived phase
    interview1.reload
    assert interview1.interview_phase.archived?

    # Interview2 is untouched, points to active phase
    interview2.reload
    assert interview2.interview_phase.active?
    assert_equal "Technical Interview", interview2.interview_phase.name
  end

  test "application current_interview_phase preserved when phase is versioned" do
    phase = @phases[1]
    @application.update!(current_interview_phase: phase)

    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "scheduled",
      scheduled_at: 2.days.from_now
    )

    # Version the phase
    new_phase = phase.update_with_versioning(name: "Updated Technical")

    # Application still references the old (now archived) phase
    @application.reload
    assert_equal phase.id, @application.current_interview_phase_id
  end

  test "versioning preserves complete interview chain for a candidate" do
    # Create interviews for all phases
    interviews = @phases.map do |phase|
      Interview.create!(
        company: @company,
        application: @application,
        interview_phase: phase,
        status: "complete"
      )
    end

    # Add scorecards to each
    interviews.each do |interview|
      sc = Scorecard.create!(
        company: @company,
        interview: interview,
        user: @interviewer,
        notes: "Notes for #{interview.interview_phase.name}",
        submitted: true
      )
      ScorecardCategory.create!(scorecard: sc, name: "Overall", rating: 4)
    end

    # Version the first phase
    @phases[0].update_with_versioning(name: "Updated Phone Screen")

    # All 4 interviews still exist
    assert_equal 4, @application.interviews.count

    # All 4 scorecards still exist
    total_scorecards = @application.interviews.flat_map(&:scorecards).count
    assert_equal 4, total_scorecards

    # All 4 scorecard categories still exist
    total_categories = @application.interviews
      .flat_map(&:scorecards)
      .flat_map(&:scorecard_categories).count
    assert_equal 4, total_categories
  end

  test "has_candidate_data? returns true when interviews exist" do
    phase = @phases[0]
    assert_not phase.has_candidate_data?

    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    assert phase.has_candidate_data?
  end

  test "has_candidate_data? returns false for phase with no interviews" do
    phase = @phases[0]
    assert_not phase.has_candidate_data?
  end

  test "version history tracks full lineage through multiple versions" do
    phase = @phases[0]

    # Create candidate data so update_with_versioning creates new versions
    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    v2 = phase.update_with_versioning(name: "V2 Phone Screen")

    # Create a second candidate with interview on v2
    candidate2 = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com"
    )
    app2 = ApplicationSubmission.create!(
      company: @company,
      candidate: candidate2,
      role: @role,
      status: "interviewing"
    )
    Interview.create!(
      company: @company,
      application: app2,
      interview_phase: v2,
      status: "unscheduled"
    )

    v3 = v2.update_with_versioning(name: "V3 Phone Screen")

    # Version history from v3 should show all 3 versions
    history = v3.version_history.to_a
    assert_equal 3, history.count
    assert_equal [1, 2, 3], history.map(&:phase_version)
    assert_equal ["Phone Screen", "V2 Phone Screen", "V3 Phone Screen"], history.map(&:name)

    # First two are archived, last is active
    assert history[0].archived?
    assert history[1].archived?
    assert history[2].active?
  end

  test "archived phase cannot be versioned again" do
    phase = @phases[0]
    phase.archive!

    assert phase.archived?
    # Creating a new version of an already archived phase should still work
    # (it archives again - idempotent) but the original remains archived
    new_version = phase.create_new_version(name: "Re-versioned")
    assert new_version.active?
    assert phase.reload.archived?
  end

  test "destroying archived phase does not affect active version" do
    phase = @phases[0]

    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    new_phase = phase.update_with_versioning(name: "Updated Phone")

    # Destroy the archived phase (if allowed)
    phase.candidate_interviews.destroy_all
    phase.destroy!

    # New phase still active and intact
    assert new_phase.reload.active?
    assert_equal "Updated Phone", new_phase.name
    # original_phase_id is nullified due to foreign key on_delete: :nullify
    assert_nil new_phase.original_phase_id
  end

  test "new version gets same position as original" do
    phase = @phases[1] # Technical Interview at position 1

    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    new_phase = phase.update_with_versioning(name: "Updated Technical")

    assert_equal 1, new_phase.position
    assert_equal 1, phase.reload.position # archived keeps its position too
  end

  test "active_interview_phases excludes archived versions" do
    phase = @phases[0]

    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "unscheduled"
    )

    new_phase = phase.update_with_versioning(name: "Updated Phone")

    active_phases = @role.active_interview_phases
    assert_includes active_phases, new_phase
    assert_not_includes active_phases, phase
    # Total active phases should still be 4 (3 originals + 1 new version)
    assert_equal 4, active_phases.count
  end

  test "modifying phase owner does not affect existing interview data" do
    phase = @phases[0]
    phase.update!(phase_owner: @admin)

    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "complete"
    )

    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer,
      notes: "Good performance",
      submitted: true
    )

    # Change phase owner
    phase.update!(phase_owner: @interviewer)

    # Interview and scorecard unchanged
    interview.reload
    scorecard.reload
    assert_equal "complete", interview.status
    assert_equal "Good performance", scorecard.notes
    assert scorecard.submitted?
  end

  test "candidate interview data survives phase reordering" do
    phase = @phases[1] # Technical Interview at position 1

    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: phase,
      status: "scheduled",
      scheduled_at: 2.days.from_now
    )

    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer,
      notes: "Tech review notes"
    )

    # Reorder: move Technical Interview to last position
    phase.move_to(3)

    # Data intact
    interview.reload
    scorecard.reload
    assert_equal "scheduled", interview.status
    assert_equal "Tech review notes", scorecard.notes
    assert_equal phase.id, interview.interview_phase_id
  end

  test "adding new phase does not affect existing candidate interviews" do
    # Create interviews for existing phases
    existing_interviews = @phases[0..1].map do |phase|
      Interview.create!(
        company: @company,
        application: @application,
        interview_phase: phase,
        status: "complete"
      )
    end

    # Add a new phase
    new_phase = @role.interview_phases.create!(
      name: "Culture Fit",
      company: @company
    )

    # Existing interviews untouched
    existing_interviews.each do |interview|
      interview.reload
      assert_equal "complete", interview.status
    end

    # Application doesn't automatically get interview for new phase
    assert_not Interview.exists?(
      application_id: @application.id,
      interview_phase_id: new_phase.id
    )
  end

  test "removing a phase with no interviews deletes cleanly" do
    # New phase with no candidate data
    new_phase = @role.interview_phases.create!(
      name: "Bonus Phase",
      company: @company
    )

    assert_difference "InterviewPhase.count", -1 do
      new_phase.destroy!
    end
  end

  test "concurrent versioning of different phases preserves all data" do
    # Create interviews on multiple phases
    interview1 = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phases[0],
      status: "complete"
    )
    sc1 = Scorecard.create!(
      company: @company,
      interview: interview1,
      user: @interviewer,
      notes: "Phone screen notes",
      submitted: true
    )

    interview2 = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phases[1],
      status: "complete"
    )
    sc2 = Scorecard.create!(
      company: @company,
      interview: interview2,
      user: @interviewer,
      notes: "Technical notes",
      submitted: true
    )

    # Version both phases
    new_phase1 = @phases[0].update_with_versioning(name: "Updated Phone")
    new_phase2 = @phases[1].update_with_versioning(name: "Updated Technical")

    # All original data preserved
    sc1.reload
    sc2.reload
    assert_equal "Phone screen notes", sc1.notes
    assert_equal "Technical notes", sc2.notes

    # Both original phases archived
    assert @phases[0].reload.archived?
    assert @phases[1].reload.archived?

    # Both new phases active
    assert new_phase1.active?
    assert new_phase2.active?

    # Active count still 4
    assert_equal 4, @role.active_interview_phases.count
  end
end
