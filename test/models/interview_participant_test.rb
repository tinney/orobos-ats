# frozen_string_literal: true

require "test_helper"

class InterviewParticipantTest < ActiveSupport::TestCase
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
    @interview = Interview.create!(
      company: @company,
      application: @application,
      interview_phase: @phase
    )
    @user = User.create!(
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

  test "valid participant" do
    participant = InterviewParticipant.new(interview: @interview, user: @user)
    assert participant.valid?
  end

  test "user uniqueness per interview" do
    InterviewParticipant.create!(interview: @interview, user: @user)
    dup = InterviewParticipant.new(interview: @interview, user: @user)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "is already assigned to this interview"
  end

  test "same user can participate in different interviews" do
    InterviewParticipant.create!(interview: @interview, user: @user)

    phase2 = @role.interview_phases.ordered.second
    interview2 = Interview.create!(company: @company, application: @application, interview_phase: phase2)
    participant = InterviewParticipant.new(interview: interview2, user: @user)
    assert participant.valid?
  end
end
