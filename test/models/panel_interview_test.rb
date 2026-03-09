# frozen_string_literal: true

require "test_helper"

class PanelInterviewTest < ActiveSupport::TestCase
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
    @interviewer1 = User.create!(
      company: @company,
      first_name: "Alice",
      last_name: "Smith",
      email: "alice@example.com",
      role: "interviewer"
    )
    @interviewer2 = User.create!(
      company: @company,
      first_name: "Bob",
      last_name: "Jones",
      email: "bob@example.com",
      role: "interviewer"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Associations ---

  test "belongs to interview" do
    pi = PanelInterview.create!(interview: @interview, user: @interviewer1)
    assert_equal @interview, pi.interview
  end

  test "belongs to user" do
    pi = PanelInterview.create!(interview: @interview, user: @interviewer1)
    assert_equal @interviewer1, pi.user
  end

  test "interview has many panel_interviews" do
    PanelInterview.create!(interview: @interview, user: @interviewer1)
    PanelInterview.create!(interview: @interview, user: @interviewer2)
    assert_equal 2, @interview.panel_interviews.count
  end

  test "interview has many panel_members through panel_interviews" do
    PanelInterview.create!(interview: @interview, user: @interviewer1)
    PanelInterview.create!(interview: @interview, user: @interviewer2)
    assert_includes @interview.panel_members, @interviewer1
    assert_includes @interview.panel_members, @interviewer2
  end

  test "user has many panel_interviews" do
    assert_respond_to @interviewer1, :panel_interviews
  end

  test "user has many panel_assigned_interviews through panel_interviews" do
    PanelInterview.create!(interview: @interview, user: @interviewer1)
    assert_includes @interviewer1.panel_assigned_interviews, @interview
  end

  # --- Validations ---

  test "validates uniqueness of user within interview" do
    PanelInterview.create!(interview: @interview, user: @interviewer1)
    duplicate = PanelInterview.new(interview: @interview, user: @interviewer1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already a panel member for this interview"
  end

  test "same user can be on panels for different interviews" do
    phase2 = @role.interview_phases.ordered.second
    candidate2 = Candidate.create!(company: @company, first_name: "Bob", last_name: "Doe", email: "bob2@example.com")
    app2 = ApplicationSubmission.create!(company: @company, candidate: candidate2, role: @role)
    interview2 = Interview.create!(company: @company, application: app2, interview_phase: phase2)

    pi1 = PanelInterview.create!(interview: @interview, user: @interviewer1)
    pi2 = PanelInterview.create!(interview: interview2, user: @interviewer1)
    assert pi1.persisted?
    assert pi2.persisted?
  end

  # --- At least one panel member validation ---

  test "cannot remove the last panel member" do
    pi = PanelInterview.create!(interview: @interview, user: @interviewer1)

    assert_no_difference "PanelInterview.count" do
      assert_not pi.destroy
    end
    assert_includes pi.errors[:base], "Cannot remove the last panel member from an interview"
  end

  test "can remove a panel member when others remain" do
    pi1 = PanelInterview.create!(interview: @interview, user: @interviewer1)
    PanelInterview.create!(interview: @interview, user: @interviewer2)

    assert_difference "PanelInterview.count", -1 do
      assert pi1.destroy
    end
  end

  # --- Interview convenience methods ---

  test "add_panel_member! creates panel_interview record" do
    assert_difference "PanelInterview.count", 1 do
      @interview.add_panel_member!(@interviewer1)
    end
    assert_includes @interview.panel_members, @interviewer1
  end

  test "add_panel_member! is idempotent" do
    @interview.add_panel_member!(@interviewer1)
    assert_no_difference "PanelInterview.count" do
      @interview.add_panel_member!(@interviewer1)
    end
  end

  test "remove_panel_member! removes panel member when others exist" do
    @interview.add_panel_member!(@interviewer1)
    @interview.add_panel_member!(@interviewer2)
    assert_difference "PanelInterview.count", -1 do
      @interview.remove_panel_member!(@interviewer1)
    end
    assert_not_includes @interview.reload.panel_members, @interviewer1
  end

  test "remove_panel_member! raises when removing last member" do
    @interview.add_panel_member!(@interviewer1)
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @interview.remove_panel_member!(@interviewer1)
    end
  end

  test "has_panel_members? returns true when panel has members" do
    @interview.add_panel_member!(@interviewer1)
    assert @interview.has_panel_members?
  end

  test "has_panel_members? returns false when panel is empty" do
    assert_not @interview.has_panel_members?
  end

  # --- Cascade delete ---

  test "panel_interviews are destroyed when interview is destroyed" do
    @interview.add_panel_member!(@interviewer1)
    @interview.add_panel_member!(@interviewer2)
    assert_difference "PanelInterview.count", -2 do
      @interview.destroy!
    end
  end

  test "user with panel_interviews cannot be hard-deleted (data preservation)" do
    @interview.add_panel_member!(@interviewer1)
    assert_no_difference "PanelInterview.count" do
      assert_raises(ActiveRecord::RecordNotDestroyed) do
        @interviewer1.destroy!
      end
    end
  end
end
