require "test_helper"

class InterviewPhaseVersioningTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Versioning Corp", subdomain: "versioncorp")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company,
      email: "admin@versioncorp.example.com",
      first_name: "Admin",
      last_name: "User",
      role: "admin"
    )

    @interviewer = User.create!(
      company: @company,
      email: "interviewer@versioncorp.example.com",
      first_name: "Inter",
      last_name: "Viewer",
      role: "interviewer"
    )

    @role = Role.create!(company: @company, title: "Engineer")
    @phase = @role.interview_phases.find_by(name: "Phone Screen")
    @phase.update!(phase_owner: @admin)

    @candidate = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )

    @application = ApplicationSubmission.create!(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "interviewing",
      current_interview_phase_id: @phase.id
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Core versioning with interview data preservation ---

  test "versioning preserves interviews linked to archived phase" do
    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "complete"
    )

    new_phase = @phase.update_with_versioning(name: "Updated Phone Screen")

    # Old interview remains linked to the archived phase
    interview.reload
    assert_equal @phase.id, interview.interview_phase_id
    assert @phase.reload.archived?
    assert_equal "Phone Screen", @phase.name
  end

  test "versioning preserves scorecards linked to archived phase" do
    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "complete"
    )

    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer,
      notes: "Great candidate"
    )
    ScorecardCategory.create!(
      scorecard: scorecard,
      name: "Technical Skills",
      rating: 4
    )

    new_phase = @phase.update_with_versioning(name: "Updated Phone Screen")

    # Scorecard and ratings remain intact on old interview/phase
    scorecard.reload
    assert_equal interview.id, scorecard.interview_id
    assert_equal "Great candidate", scorecard.notes
    assert_equal 4, scorecard.scorecard_categories.first.rating

    # The interview still belongs to the archived phase
    interview.reload
    assert_equal @phase.id, interview.interview_phase_id
    assert @phase.reload.archived?
  end

  test "versioning preserves panel members on interviews of archived phase" do
    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "scheduled",
      scheduled_at: 1.day.from_now
    )
    interview.assign_interviewer!(@interviewer)
    interview.add_panel_member!(@admin)

    new_phase = @phase.update_with_versioning(name: "New Phone Screen")

    interview.reload
    assert interview.interviewers.include?(@interviewer)
    assert interview.panel_members.include?(@admin)
    assert_equal @phase.id, interview.interview_phase_id
  end

  # --- Phase owner preservation ---

  test "new version inherits phase_owner from old version" do
    new_phase = @phase.create_new_version(name: "Updated Phone Screen")

    assert_equal @admin.id, new_phase.phase_owner_id
  end

  test "new version can override phase_owner" do
    new_phase = @phase.create_new_version(
      name: "Updated Phone Screen",
      phase_owner_id: @interviewer.id
    )

    assert_equal @interviewer.id, new_phase.phase_owner_id
  end

  # --- Application current_interview_phase migration ---

  test "application without interview is migrated to new phase version" do
    # Application is at this phase but has no interview yet
    assert_equal @phase.id, @application.current_interview_phase_id

    new_phase = @phase.create_new_version(name: "Updated Phone Screen")

    @application.reload
    assert_equal new_phase.id, @application.current_interview_phase_id
  end

  test "application with interview stays on archived phase" do
    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "scheduled",
      scheduled_at: 1.day.from_now
    )

    new_phase = @phase.create_new_version(name: "Updated Phone Screen")

    @application.reload
    # Application keeps reference to archived phase because it has interview data
    assert_equal @phase.id, @application.current_interview_phase_id
  end

  test "mixed applications: some migrated, some preserved" do
    # Second candidate with interview
    candidate2 = Candidate.create!(
      company: @company,
      first_name: "Bob",
      last_name: "Smith",
      email: "bob@example.com"
    )
    app_with_interview = ApplicationSubmission.create!(
      company: @company,
      candidate: candidate2,
      role: @role,
      status: "interviewing",
      current_interview_phase_id: @phase.id
    )
    Interview.create!(
      company: @company,
      application: app_with_interview,
      interview_phase: @phase,
      status: "complete"
    )

    # @application has NO interview for this phase
    new_phase = @phase.create_new_version(name: "Updated Phone Screen")

    # App without interview → migrated
    @application.reload
    assert_equal new_phase.id, @application.current_interview_phase_id

    # App with interview → stays on archived phase
    app_with_interview.reload
    assert_equal @phase.id, app_with_interview.current_interview_phase_id
  end

  # --- update_with_versioning triggers versioning when candidate data exists ---

  test "update_with_versioning creates new version when interviews exist" do
    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "unscheduled"
    )

    result = @phase.update_with_versioning(name: "Renamed Phone Screen")

    assert_not_equal @phase.id, result.id
    assert result.active?
    assert @phase.reload.archived?
    assert_equal "Renamed Phone Screen", result.name
    assert_equal "Phone Screen", @phase.name
  end

  test "update_with_versioning updates in place when no interviews" do
    # Remove all interviews (application has none by default)
    result = @phase.update_with_versioning(name: "Renamed Phone Screen")

    assert_equal @phase.id, result.id
    assert_equal "Renamed Phone Screen", result.name
    assert result.active?
  end

  # --- Multiple successive versions preserve all historical data ---

  test "three versions preserve all historical interviews and scorecards" do
    # Version 1: create interview with scorecard
    interview_v1 = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "complete"
    )
    scorecard_v1 = Scorecard.create!(
      company: @company,
      interview: interview_v1,
      user: @interviewer,
      notes: "V1 feedback"
    )

    # Version 2
    v2 = @phase.create_new_version(name: "Phone Screen v2")

    # New candidate on v2
    candidate2 = Candidate.create!(
      company: @company,
      first_name: "Alice",
      last_name: "Jones",
      email: "alice@example.com"
    )
    app2 = ApplicationSubmission.create!(
      company: @company,
      candidate: candidate2,
      role: @role,
      status: "interviewing",
      current_interview_phase_id: v2.id
    )
    interview_v2 = Interview.create!(
      company: @company,
      application: app2,
      interview_phase: v2,
      status: "complete"
    )
    scorecard_v2 = Scorecard.create!(
      company: @company,
      interview: interview_v2,
      user: @interviewer,
      notes: "V2 feedback"
    )

    # Version 3
    v3 = v2.create_new_version(name: "Phone Screen v3")

    # Verify all historical data preserved
    assert_equal "V1 feedback", scorecard_v1.reload.notes
    assert_equal @phase.id, interview_v1.reload.interview_phase_id
    assert @phase.reload.archived?

    assert_equal "V2 feedback", scorecard_v2.reload.notes
    assert_equal v2.id, interview_v2.reload.interview_phase_id
    assert v2.reload.archived?

    assert v3.active?
    assert_equal 3, v3.phase_version

    # Version history includes all three
    history = v3.version_history
    assert_equal 3, history.count
    assert_equal [1, 2, 3], history.pluck(:phase_version)
  end

  # --- Helper methods ---

  test "root_phase_id returns self id for original phase" do
    assert_equal @phase.id, @phase.root_phase_id
  end

  test "root_phase_id returns original_phase_id for versioned phase" do
    v2 = @phase.create_new_version(name: "V2")
    assert_equal @phase.id, v2.root_phase_id
  end

  test "latest_active_version returns the active version" do
    v2 = @phase.create_new_version(name: "V2")
    v3 = v2.create_new_version(name: "V3")

    assert_equal v3.id, @phase.latest_active_version.id
    assert_equal v3.id, v2.latest_active_version.id
    assert_equal v3.id, v3.latest_active_version.id
  end

  test "versioned? returns false for unversioned phase" do
    fresh_role = Role.create!(company: @company, title: "Fresh Role")
    fresh_phase = fresh_role.interview_phases.first
    assert_not fresh_phase.versioned?
  end

  test "versioned? returns true for phase with versions" do
    @phase.create_new_version(name: "V2")
    assert @phase.versioned?
  end

  test "versioned? returns true for phase that is a version" do
    v2 = @phase.create_new_version(name: "V2")
    assert v2.versioned?
  end

  # --- Edge cases ---

  test "versioning phase with cancelled interview still preserves data" do
    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "cancelled"
    )
    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer,
      notes: "Cancelled but preserved"
    )

    new_phase = @phase.update_with_versioning(name: "New Name")

    assert_not_equal @phase.id, new_phase.id
    assert_equal "Cancelled but preserved", scorecard.reload.notes
    assert_equal @phase.id, interview.reload.interview_phase_id
  end

  test "application on different phase is not affected by versioning" do
    other_phase = @role.interview_phases.find_by(name: "Technical Interview")
    @application.update_column(:current_interview_phase_id, other_phase.id)

    # Create interview on @phase from another app
    candidate2 = Candidate.create!(
      company: @company,
      first_name: "Bob",
      last_name: "Smith",
      email: "bob2@example.com"
    )
    other_app = ApplicationSubmission.create!(
      company: @company,
      candidate: candidate2,
      role: @role,
      status: "interviewing",
      current_interview_phase_id: @phase.id
    )
    Interview.create!(
      company: @company,
      application: other_app,
      interview_phase: @phase,
      status: "complete"
    )

    @phase.create_new_version(name: "New Phone Screen")

    # Application on different phase is untouched
    @application.reload
    assert_equal other_phase.id, @application.current_interview_phase_id
  end

  test "has_candidate_data? returns true when interviews exist" do
    Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "unscheduled"
    )
    assert @phase.has_candidate_data?
  end

  test "has_candidate_data? returns false when no interviews exist" do
    assert_not @phase.has_candidate_data?
  end

  test "scorecard category ratings preserved across version chain" do
    interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "complete"
    )
    scorecard = Scorecard.create!(
      company: @company,
      interview: interview,
      user: @interviewer
    )
    ScorecardCategory.create!(scorecard: scorecard, name: "Communication", rating: 5)
    ScorecardCategory.create!(scorecard: scorecard, name: "Technical", rating: 3)

    @phase.create_new_version(name: "Updated Phase")

    scorecard.reload
    assert_equal 4.0, scorecard.average_rating
    categories = scorecard.scorecard_categories.order(:name)
    assert_equal "Communication", categories.first.name
    assert_equal 5, categories.first.rating
    assert_equal "Technical", categories.last.name
    assert_equal 3, categories.last.rating
  end
end
