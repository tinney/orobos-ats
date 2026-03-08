# frozen_string_literal: true

require "test_helper"

class InterviewTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Co", subdomain: "testco")
    ActsAsTenant.current_tenant = @company
    @role = Role.create!(company: @company, title: "Engineer")
    @phase = @role.interview_phases.first
    @candidate = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )
    @application = ApplicationSubmission.create!(
      company: @company,
      candidate: @candidate,
      role: @role
    )
    @interviewer = User.create!(
      company: @company,
      first_name: "Bob",
      last_name: "Reviewer",
      email: "bob@example.com",
      role: "interviewer"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # ==========================================
  # Basic validations
  # ==========================================

  test "valid interview" do
    interview = Interview.new(
      company: @company,
      application: @application,
      interview_phase: @phase
    )
    assert interview.valid?
  end

  test "one interview per phase per application" do
    Interview.create!(company: @company, application: @application, interview_phase: @phase)
    dup = Interview.new(company: @company, application: @application, interview_phase: @phase)
    assert_not dup.valid?
    assert_includes dup.errors[:application_id], "already has an interview for this phase"
  end

  test "created without scheduled_at is unscheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert interview.unscheduled?
    assert_not interview.scheduled?
    assert_nil interview.scheduled_at
  end

  test "status must be valid" do
    interview = Interview.new(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "invalid_status"
    )
    assert_not interview.valid?
    assert_includes interview.errors[:status], "is not included in the list"
  end

  test "scheduled status requires scheduled_at" do
    interview = Interview.new(
      company: @company,
      application: @application,
      interview_phase: @phase,
      status: "scheduled"
    )
    assert_not interview.valid?
    assert_includes interview.errors[:scheduled_at], "can't be blank"
  end

  test "duration_minutes must be positive" do
    interview = Interview.new(
      company: @company,
      application: @application,
      interview_phase: @phase,
      duration_minutes: 0
    )
    assert_not interview.valid?
    assert_includes interview.errors[:duration_minutes], "must be greater than 0"
  end

  test "duration_minutes allows nil" do
    interview = Interview.new(
      company: @company,
      application: @application,
      interview_phase: @phase,
      duration_minutes: nil
    )
    assert interview.valid?
  end

  # ==========================================
  # State machine - VALID_TRANSITIONS constant
  # ==========================================

  test "VALID_TRANSITIONS defines allowed state changes" do
    assert_equal %w[scheduled cancelled], Interview::VALID_TRANSITIONS["unscheduled"]
    assert_equal %w[complete cancelled unscheduled], Interview::VALID_TRANSITIONS["scheduled"]
    assert_equal [], Interview::VALID_TRANSITIONS["complete"]
    assert_equal %w[unscheduled], Interview::VALID_TRANSITIONS["cancelled"]
  end

  # ==========================================
  # State query helpers
  # ==========================================

  test "terminal? returns true for complete" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert interview.terminal?
  end

  test "terminal? returns false for non-complete states" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_not interview.terminal?
  end

  test "active? returns true for unscheduled and scheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert interview.active?
    interview.schedule!(2.days.from_now)
    assert interview.active?
  end

  test "active? returns false for complete and cancelled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_not interview.active?
  end

  # ==========================================
  # can_transition_to?
  # ==========================================

  test "can_transition_to? from unscheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert interview.can_transition_to?("scheduled")
    assert interview.can_transition_to?("cancelled")
    assert_not interview.can_transition_to?("complete")
    assert_not interview.can_transition_to?("unscheduled")
  end

  test "can_transition_to? from scheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    assert interview.can_transition_to?("complete")
    assert interview.can_transition_to?("cancelled")
    assert interview.can_transition_to?("unscheduled")
    assert_not interview.can_transition_to?("scheduled")
  end

  test "can_transition_to? from complete (terminal)" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_not interview.can_transition_to?("unscheduled")
    assert_not interview.can_transition_to?("scheduled")
    assert_not interview.can_transition_to?("cancelled")
  end

  test "can_transition_to? from cancelled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    assert interview.can_transition_to?("unscheduled")
    assert_not interview.can_transition_to?("scheduled")
    assert_not interview.can_transition_to?("complete")
  end

  # ==========================================
  # transition_to!
  # ==========================================

  test "transition_to! performs valid transition" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase,
      scheduled_at: 2.days.from_now, status: "scheduled")
    interview.transition_to!("complete")
    assert interview.complete?
  end

  test "transition_to! raises on invalid transition" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_raises Interview::InvalidTransitionError do
      interview.transition_to!("complete")
    end
  end

  # ==========================================
  # schedule!
  # ==========================================

  test "schedule! transitions from unscheduled to scheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    time = 2.days.from_now
    interview.schedule!(time)
    interview.reload
    assert interview.scheduled?
    assert_in_delta time.to_i, interview.scheduled_at.to_i, 1
  end

  test "schedule! with duration and location" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now, duration: 45, location: "Room 101")
    interview.reload
    assert_equal 45, interview.duration_minutes
    assert_equal "Room 101", interview.location
  end

  test "schedule! raises from complete state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_raises Interview::InvalidTransitionError do
      interview.schedule!(3.days.from_now)
    end
  end

  test "schedule! raises from cancelled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    assert_raises Interview::InvalidTransitionError do
      interview.schedule!(3.days.from_now)
    end
  end

  test "schedule! raises from already scheduled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    assert_raises Interview::InvalidTransitionError do
      interview.schedule!(3.days.from_now)
    end
  end

  # ==========================================
  # complete!
  # ==========================================

  test "complete! transitions from scheduled to complete" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    interview.reload
    assert interview.complete?
    assert_not_nil interview.completed_at
  end

  test "complete! raises from unscheduled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_raises Interview::InvalidTransitionError do
      interview.complete!
    end
  end

  test "complete! raises from cancelled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    assert_raises Interview::InvalidTransitionError do
      interview.complete!
    end
  end

  # ==========================================
  # cancel!
  # ==========================================

  test "cancel! transitions from unscheduled to cancelled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    interview.reload
    assert interview.cancelled?
    assert_not_nil interview.cancelled_at
  end

  test "cancel! transitions from scheduled to cancelled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.cancel!(reason: "Candidate unavailable")
    interview.reload
    assert interview.cancelled?
    assert_equal "Candidate unavailable", interview.cancelled_reason
  end

  test "cancel! raises from complete state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_raises Interview::InvalidTransitionError do
      interview.cancel!
    end
  end

  test "cancel! raises from already cancelled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    assert_raises Interview::InvalidTransitionError do
      interview.cancel!
    end
  end

  # ==========================================
  # reopen!
  # ==========================================

  test "reopen! transitions from cancelled to unscheduled" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!(reason: "oops")
    interview.reopen!
    interview.reload
    assert interview.unscheduled?
    assert_nil interview.scheduled_at
    assert_nil interview.cancelled_at
    assert_nil interview.cancelled_reason
  end

  test "reopen! raises from unscheduled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_raises Interview::InvalidTransitionError do
      interview.reopen!
    end
  end

  test "reopen! raises from complete state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_raises Interview::InvalidTransitionError do
      interview.reopen!
    end
  end

  # ==========================================
  # reschedule!
  # ==========================================

  test "reschedule! updates time and tracks history" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    original_time = 2.days.from_now
    interview.schedule!(original_time)

    new_time = 3.days.from_now
    interview.reschedule!(new_time, reason: "Conflict")
    interview.reload

    assert interview.scheduled?
    assert_in_delta new_time.to_i, interview.scheduled_at.to_i, 1
    assert_equal 1, interview.reschedule_count
    assert_equal "Conflict", interview.reschedule_reason
    assert_equal 1, interview.schedule_history.length
  end

  test "reschedule! increments count on multiple reschedules" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(1.day.from_now)

    interview.reschedule!(2.days.from_now, reason: "First reschedule")
    assert_equal 1, interview.reschedule_count

    interview.reschedule!(3.days.from_now, reason: "Second reschedule")
    assert_equal 2, interview.reschedule_count
    assert_equal "Second reschedule", interview.reschedule_reason
    assert_equal 2, interview.schedule_history.length
  end

  test "reschedule! raises from unscheduled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_raises Interview::InvalidTransitionError do
      interview.reschedule!(3.days.from_now)
    end
  end

  test "reschedule! raises from complete state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.schedule!(2.days.from_now)
    interview.complete!
    assert_raises Interview::InvalidTransitionError do
      interview.reschedule!(3.days.from_now)
    end
  end

  test "reschedule! raises from cancelled state" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.cancel!
    assert_raises Interview::InvalidTransitionError do
      interview.reschedule!(3.days.from_now)
    end
  end

  # ==========================================
  # Full lifecycle tests
  # ==========================================

  test "full lifecycle: unscheduled -> scheduled -> complete" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert interview.unscheduled?

    interview.schedule!(2.days.from_now)
    assert interview.scheduled?

    interview.complete!
    assert interview.complete?
    assert interview.terminal?
  end

  test "full lifecycle: unscheduled -> scheduled -> cancelled -> reopened -> scheduled -> complete" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)

    interview.schedule!(2.days.from_now)
    assert interview.scheduled?

    interview.cancel!(reason: "postponed")
    assert interview.cancelled?

    interview.reopen!
    assert interview.unscheduled?

    interview.schedule!(5.days.from_now)
    assert interview.scheduled?

    interview.complete!
    assert interview.complete?
  end

  test "full lifecycle: unscheduled -> cancelled -> reopened -> scheduled with reschedule -> complete" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)

    interview.cancel!
    assert interview.cancelled?

    interview.reopen!
    assert interview.unscheduled?

    interview.schedule!(2.days.from_now)
    interview.reschedule!(4.days.from_now, reason: "moved")
    assert interview.scheduled?
    assert_equal 1, interview.reschedule_count

    interview.complete!
    assert interview.complete?
    assert interview.terminal?
  end

  # ==========================================
  # Validation prevents invalid direct assignment
  # ==========================================

  test "validation blocks invalid status transition via direct update" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.status = "complete"
    assert_not interview.valid?
    assert_includes interview.errors[:status], "cannot transition from 'unscheduled' to 'complete'"
  end

  test "validation allows valid status transition via direct update" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.status = "cancelled"
    assert interview.valid?
  end

  # ==========================================
  # Scopes
  # ==========================================

  test "scopes filter by status" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_includes Interview.unscheduled, interview
    assert_includes Interview.active, interview
    assert_not_includes Interview.scheduled, interview

    interview.schedule!(2.days.from_now)
    assert_includes Interview.scheduled, interview
    assert_includes Interview.active, interview

    interview.complete!
    assert_includes Interview.complete, interview
    assert_not_includes Interview.active, interview
  end

  test "scheduled scope" do
    unscheduled = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    phase2 = @role.interview_phases.ordered.second
    candidate2 = Candidate.create!(company: @company, first_name: "Al", last_name: "Doe", email: "al@example.com")
    app2 = ApplicationSubmission.create!(company: @company, candidate: candidate2, role: @role)
    scheduled = Interview.create!(company: @company, application: app2, interview_phase: phase2, scheduled_at: 1.day.from_now, status: "scheduled")

    assert_includes Interview.scheduled, scheduled
    assert_not_includes Interview.scheduled, unscheduled
    assert_includes Interview.unscheduled, unscheduled
    assert_not_includes Interview.unscheduled, scheduled
  end

  # ==========================================
  # Interviewer assignment (preserved from AC 25)
  # ==========================================

  test "assign_interviewer! creates participant" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_difference "InterviewParticipant.count", 1 do
      interview.assign_interviewer!(@interviewer)
    end
    assert_includes interview.interviewers, @interviewer
  end

  test "assign_interviewer! is idempotent" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)
    assert_no_difference "InterviewParticipant.count" do
      interview.assign_interviewer!(@interviewer)
    end
  end

  test "remove_interviewer! removes participant" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)
    assert_difference "InterviewParticipant.count", -1 do
      interview.remove_interviewer!(@interviewer)
    end
  end

  test "destroys participants when destroyed" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)
    assert_difference "InterviewParticipant.count", -1 do
      interview.destroy!
    end
  end

  # ==========================================
  # Panel membership
  # ==========================================

  test "panel_member? returns true for assigned interviewer" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)
    assert interview.panel_member?(@interviewer)
  end

  test "panel_member? returns false for unassigned user" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    other_user = User.create!(
      company: @company,
      first_name: "Other",
      last_name: "User",
      email: "other@example.com",
      role: "interviewer"
    )
    assert_not interview.panel_member?(other_user)
  end

  test "panel_member? returns false for nil user" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_not interview.panel_member?(nil)
  end

  # ==========================================
  # for_user scope
  # ==========================================

  test "for_user returns interviews where user is an interviewer" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)

    results = Interview.for_user(@interviewer)
    assert_includes results, interview
  end

  test "for_user returns interviews where user is a panel member" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.add_panel_member!(@interviewer)

    results = Interview.for_user(@interviewer)
    assert_includes results, interview
  end

  test "for_user returns interview only once when user is both interviewer and panel member" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)
    interview.add_panel_member!(@interviewer)

    results = Interview.for_user(@interviewer)
    assert_equal 1, results.where(id: interview.id).count
  end

  test "for_user excludes interviews not assigned to user" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    other_user = User.create!(
      company: @company,
      first_name: "Alice",
      last_name: "Other",
      email: "alice@example.com",
      role: "interviewer"
    )
    interview.assign_interviewer!(other_user)

    results = Interview.for_user(@interviewer)
    assert_not_includes results, interview
  end

  test "for_user returns empty when user has no assignments" do
    Interview.create!(company: @company, application: @application, interview_phase: @phase)
    assert_empty Interview.for_user(@interviewer)
  end

  test "for_user returns interviews across multiple roles" do
    interview1 = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview1.assign_interviewer!(@interviewer)

    role2 = Role.create!(company: @company, title: "Designer")
    phase2 = role2.interview_phases.first
    candidate2 = Candidate.create!(company: @company, first_name: "Sam", last_name: "Smith", email: "sam@example.com")
    app2 = ApplicationSubmission.create!(company: @company, candidate: candidate2, role: role2)
    interview2 = Interview.create!(company: @company, application: app2, interview_phase: phase2)
    interview2.assign_interviewer!(@interviewer)

    results = Interview.for_user(@interviewer)
    assert_includes results, interview1
    assert_includes results, interview2
    assert_equal 2, results.count
  end

  test "for_user eager loads application with candidate and role" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)

    results = Interview.for_user(@interviewer)
    loaded = results.first
    assert loaded.association(:application).loaded?
    assert loaded.application.association(:candidate).loaded?
    assert loaded.application.association(:role).loaded?
  end

  test "for_user orders scheduled interviews first" do
    phase2 = @role.interview_phases.ordered.second
    candidate2 = Candidate.create!(company: @company, first_name: "Al", last_name: "Two", email: "al2@example.com")
    app2 = ApplicationSubmission.create!(company: @company, candidate: candidate2, role: @role)

    unscheduled = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    unscheduled.assign_interviewer!(@interviewer)

    scheduled = Interview.create!(company: @company, application: app2, interview_phase: phase2, scheduled_at: 1.day.from_now, status: "scheduled")
    scheduled.assign_interviewer!(@interviewer)

    results = Interview.for_user(@interviewer).to_a
    assert_equal scheduled, results.first
    assert_equal unscheduled, results.second
  end

  test "for_user can be chained with status scopes" do
    interview = Interview.create!(company: @company, application: @application, interview_phase: @phase)
    interview.assign_interviewer!(@interviewer)

    assert_equal 1, Interview.for_user(@interviewer).active.count
    assert_equal 0, Interview.for_user(@interviewer).complete.count
  end

  # ==========================================
  # Tenant scoping
  # ==========================================

  test "tenant scoping" do
    Interview.create!(company: @company, application: @application, interview_phase: @phase)
    other_company = Company.create!(name: "Other Co", subdomain: "otherco")
    ActsAsTenant.current_tenant = other_company
    assert_equal 0, Interview.count
  end
end
