# frozen_string_literal: true

require "test_helper"

class UserSoftDeletePreservationTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp-softdel")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company,
      email: "admin-softdel@example.com",
      first_name: "Admin",
      last_name: "User",
      role: "admin"
    )

    @interviewer = User.create!(
      company: @company,
      email: "interviewer-softdel@example.com",
      first_name: "Inter",
      last_name: "Viewer",
      role: "interviewer"
    )

    @role = Role.create!(
      company: @company,
      title: "Software Engineer",
      hiring_manager: @interviewer
    )

    @phase = @role.interview_phases.first
    @phase.update!(phase_owner: @interviewer)

    @candidate = Candidate.create!(
      company: @company,
      email: "candidate-softdel@example.com",
      first_name: "John",
      last_name: "Applicant"
    )

    @application = ApplicationSubmission.create!(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "interviewing"
    )

    @interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "unscheduled"
    )

    # Create interview participant (assigns interviewer to interview)
    @participant = InterviewParticipant.create!(
      interview: @interview,
      user: @interviewer
    )

    # Create panel interview
    @panel = PanelInterview.create!(
      interview: @interview,
      user: @interviewer
    )

    # Create scorecard
    @scorecard = Scorecard.create!(
      company: @company,
      interview: @interview,
      user: @interviewer
    )

    # Create offer
    @offer = Offer.create!(
      company: @company,
      application_submission: @application,
      created_by: @interviewer,
      status: "pending",
      revision: 1
    )

    # Create role status transition
    @transition = RoleStatusTransition.create!(
      company: @company,
      role: @role,
      user: @interviewer,
      from_status: "draft",
      to_status: "published"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Core: Soft-delete does NOT destroy associated records ---

  test "soft-deleting a user preserves interview participants" do
    @interviewer.discard!
    assert @interviewer.discarded?
    assert InterviewParticipant.exists?(@participant.id)
  end

  test "soft-deleting a user preserves panel interviews" do
    @interviewer.discard!
    assert PanelInterview.exists?(@panel.id)
  end

  test "soft-deleting a user preserves scorecards" do
    @interviewer.discard!
    assert Scorecard.exists?(@scorecard.id)
  end

  test "soft-deleting a user preserves offers they created" do
    @interviewer.discard!
    assert Offer.exists?(@offer.id)
  end

  test "soft-deleting a user preserves role status transitions" do
    @interviewer.discard!
    assert RoleStatusTransition.exists?(@transition.id)
  end

  test "soft-deleting a user preserves role hiring_manager assignment" do
    @interviewer.discard!
    @role.reload
    assert_equal @interviewer.id, @role.hiring_manager_id
  end

  test "soft-deleting a user preserves interview phase owner assignment" do
    @interviewer.discard!
    @phase.reload
    assert_equal @interviewer.id, @phase.phase_owner_id
  end

  # --- Unscoped lookups: associations still resolve to soft-deleted users ---

  test "scorecard.user returns soft-deleted user" do
    @interviewer.discard!
    @scorecard.reload
    assert_not_nil @scorecard.user
    assert_equal @interviewer.id, @scorecard.user.id
    assert @scorecard.user.discarded?
  end

  test "interview_participant.user returns soft-deleted user" do
    @interviewer.discard!
    @participant.reload
    assert_not_nil @participant.user
    assert_equal @interviewer.id, @participant.user.id
    assert @participant.user.discarded?
  end

  test "panel_interview.user returns soft-deleted user" do
    @interviewer.discard!
    @panel.reload
    assert_not_nil @panel.user
    assert_equal @interviewer.id, @panel.user.id
  end

  test "offer.created_by returns soft-deleted user" do
    @interviewer.discard!
    @offer.reload
    assert_not_nil @offer.created_by
    assert_equal @interviewer.id, @offer.created_by.id
  end

  test "role.hiring_manager returns soft-deleted user" do
    @interviewer.discard!
    @role.reload
    assert_not_nil @role.hiring_manager
    assert_equal @interviewer.id, @role.hiring_manager.id
  end

  test "interview_phase.phase_owner returns soft-deleted user" do
    @interviewer.discard!
    @phase.reload
    assert_not_nil @phase.phase_owner
    assert_equal @interviewer.id, @phase.phase_owner.id
  end

  test "role_status_transition.user returns soft-deleted user" do
    @interviewer.discard!
    @transition.reload
    assert_not_nil @transition.user
    assert_equal @interviewer.id, @transition.user.id
  end

  # --- Offer revision preserves changed_by reference ---

  test "offer_revision.changed_by returns soft-deleted user" do
    # Trigger a revision by updating the offer
    @offer.update!(salary: 100_000)
    revision = @offer.offer_revisions.last
    assert_not_nil revision

    @interviewer.discard!
    revision.reload
    # changed_by_id is set from created_by_id in the Offer callback
    assert_not_nil revision.changed_by
    assert_equal @interviewer.id, revision.changed_by.id
  end

  # --- Default scope still excludes soft-deleted users from standard queries ---

  test "soft-deleted users are excluded from default User queries" do
    @interviewer.discard!
    assert_not User.exists?(@interviewer.id)
  end

  test "soft-deleted users are found with User.with_discarded" do
    @interviewer.discard!
    assert User.with_discarded.exists?(@interviewer.id)
  end

  test "soft-deleted users are found with User.only_discarded" do
    @interviewer.discard!
    assert User.only_discarded.exists?(@interviewer.id)
  end

  # --- User with associated data cannot be hard-deleted (restrict) ---

  test "hard deleting a user with scorecards is prevented" do
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @interviewer.destroy!
    end
    # User still exists
    assert User.with_discarded.exists?(@interviewer.id)
  end

  test "hard deleting a user with interview participants is prevented" do
    # Remove other associations that might trigger first
    @scorecard.destroy!
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @interviewer.destroy!
    end
    assert User.with_discarded.exists?(@interviewer.id)
  end

  # --- Eager loading with soft-deleted users ---

  test "interview eager loading includes soft-deleted interviewers" do
    @interviewer.discard!
    interview = Interview.includes(interview_participants: :user).find(@interview.id)
    participant = interview.interview_participants.first
    assert_not_nil participant.user
    assert_equal @interviewer.id, participant.user.id
  end

  test "interview eager loading includes soft-deleted panel members" do
    @interviewer.discard!
    interview = Interview.includes(panel_interviews: :user).find(@interview.id)
    panel = interview.panel_interviews.first
    assert_not_nil panel.user
    assert_equal @interviewer.id, panel.user.id
  end
end
