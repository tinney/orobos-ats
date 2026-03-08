# frozen_string_literal: true

require "test_helper"

class Admin::InterviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company,
        email: "admin@testcorp.com",
        first_name: "Alice",
        last_name: "Admin",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        email: "hm@testcorp.com",
        first_name: "Harry",
        last_name: "Manager",
        role: "hiring_manager"
      )
      @interviewer_user = User.create!(
        company: @company,
        email: "interviewer@testcorp.com",
        first_name: "Ivan",
        last_name: "Viewer",
        role: "interviewer"
      )
      @role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft"
      )
      @phase = @role.interview_phases.ordered.first
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
    end

    host! "testcorp.example.com"
  end

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  def assign_path
    assign_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
  end

  def remove_path
    remove_participant_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
  end

  def schedule_path
    schedule_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
  end

  def create_interview_with_participant!(user)
    ActsAsTenant.with_tenant(@company) do
      @interview = Interview.create!(
        company: @company,
        application: @application,
        interview_phase: @phase
      )
      @interview.assign_interviewer!(user)
    end
    @interview
  end

  # ==========================================
  # Authorization
  # ==========================================

  test "interviewer role cannot assign interviewers" do
    sign_in @interviewer_user
    post assign_path, params: { user_id: @interviewer_user.id }

    assert_redirected_to tenant_root_path
    ActsAsTenant.with_tenant(@company) do
      assert_equal 0, Interview.count
    end
  end

  test "unauthenticated user cannot assign interviewers" do
    post assign_path, params: { user_id: @interviewer_user.id }

    # Unauthenticated redirects to root domain
    assert_response :redirect
    ActsAsTenant.with_tenant(@company) do
      assert_equal 0, Interview.count
    end
  end

  # ==========================================
  # Assign — creates unscheduled interview
  # ==========================================

  test "assigning interviewer creates unscheduled interview event" do
    sign_in @admin

    post assign_path, params: { user_id: @interviewer_user.id }

    assert_response :redirect
    assert flash[:notice].present?

    ActsAsTenant.with_tenant(@company) do
      assert_equal 1, Interview.count
      assert_equal 1, InterviewParticipant.count

      interview = Interview.last
      assert_nil interview.scheduled_at
      assert interview.unscheduled?
      assert_equal @application, interview.application
      assert_equal @phase, interview.interview_phase
      assert_equal @company, interview.company
      assert_includes interview.interviewers, @interviewer_user
    end
  end

  test "assigning second interviewer reuses existing interview event" do
    sign_in @admin

    # First assignment creates the interview
    post assign_path, params: { user_id: @interviewer_user.id }

    ActsAsTenant.with_tenant(@company) do
      assert_equal 1, Interview.count
    end

    # Second assignment reuses the same interview
    second_interviewer = ActsAsTenant.with_tenant(@company) do
      User.create!(
        company: @company,
        email: "reviewer2@testcorp.com",
        first_name: "Sara",
        last_name: "Reviewer",
        role: "interviewer"
      )
    end

    post assign_path, params: { user_id: second_interviewer.id }

    ActsAsTenant.with_tenant(@company) do
      # Still only 1 interview, but 2 participants
      assert_equal 1, Interview.count
      assert_equal 2, InterviewParticipant.count
    end
  end

  test "assigning same interviewer twice shows alert" do
    sign_in @admin

    post assign_path, params: { user_id: @interviewer_user.id }
    post assign_path, params: { user_id: @interviewer_user.id }

    assert flash[:alert].present?

    ActsAsTenant.with_tenant(@company) do
      assert_equal 1, Interview.count
      assert_equal 1, InterviewParticipant.count
    end
  end

  test "hiring manager can assign interviewers" do
    sign_in @hiring_manager

    post assign_path, params: { user_id: @interviewer_user.id }

    assert_response :redirect
    assert flash[:notice].present?

    ActsAsTenant.with_tenant(@company) do
      assert_equal 1, Interview.count
    end
  end

  test "interview is created with correct company (tenant)" do
    sign_in @admin

    post assign_path, params: { user_id: @interviewer_user.id }

    ActsAsTenant.with_tenant(@company) do
      interview = Interview.last
      assert_equal @company.id, interview.company_id
    end
  end

  test "assigns interviewer to different phases independently" do
    sign_in @admin

    second_phase = ActsAsTenant.with_tenant(@company) { @role.interview_phases.ordered.second }

    # Assign to first phase
    post assign_path, params: { user_id: @interviewer_user.id }

    # Assign to second phase
    post assign_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: second_phase.id
    ), params: { user_id: @interviewer_user.id }

    ActsAsTenant.with_tenant(@company) do
      assert_equal 2, Interview.count
      assert_equal 2, InterviewParticipant.count
    end
  end

  # ==========================================
  # Remove participant
  # ==========================================

  test "remove participant from interview" do
    sign_in @admin

    # Create interview with a participant
    ActsAsTenant.with_tenant(@company) do
      @interview = Interview.create!(
        company: @company,
        application: @application,
        interview_phase: @phase
      )
      @interview.assign_interviewer!(@interviewer_user)
    end

    delete remove_path, params: { user_id: @interviewer_user.id }

    assert_response :redirect
    assert flash[:notice].present?

    ActsAsTenant.with_tenant(@company) do
      assert_equal 0, InterviewParticipant.count
    end
  end

  # ==========================================
  # Schedule — shared time slot mechanism
  # ==========================================

  test "assigned interviewer can set the time slot" do
    create_interview_with_participant!(@interviewer_user)
    sign_in @interviewer_user

    scheduled_time = 2.days.from_now.change(usec: 0)
    patch schedule_path, params: { scheduled_at: scheduled_time.iso8601 }

    assert_response :redirect
    assert_equal "Interview time slot has been updated.", flash[:notice]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.scheduled?
      assert_in_delta scheduled_time.to_i, @interview.scheduled_at.to_i, 1
    end
  end

  test "assigned interviewer can update the time slot" do
    create_interview_with_participant!(@interviewer_user)
    ActsAsTenant.with_tenant(@company) do
      @interview.update!(scheduled_at: 1.day.from_now)
    end

    sign_in @interviewer_user

    new_time = 5.days.from_now.change(usec: 0)
    patch schedule_path, params: { scheduled_at: new_time.iso8601 }

    assert_response :redirect
    assert_equal "Interview time slot has been updated.", flash[:notice]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert_in_delta new_time.to_i, @interview.scheduled_at.to_i, 1
    end
  end

  test "non-panel interviewer cannot set the time slot" do
    create_interview_with_participant!(@interviewer_user)

    # Create another interviewer who is NOT on the panel
    non_panel_user = ActsAsTenant.with_tenant(@company) do
      User.create!(
        company: @company,
        email: "outsider@testcorp.com",
        first_name: "Out",
        last_name: "Sider",
        role: "interviewer"
      )
    end

    sign_in non_panel_user

    patch schedule_path, params: { scheduled_at: 2.days.from_now.iso8601 }

    assert_response :redirect
    assert_equal "Only assigned interviewers can modify this interview.", flash[:alert]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.unscheduled?
    end
  end

  test "admin can schedule even without being on panel" do
    create_interview_with_participant!(@interviewer_user)
    sign_in @admin

    scheduled_time = 3.days.from_now.change(usec: 0)
    patch schedule_path, params: { scheduled_at: scheduled_time.iso8601 }

    assert_response :redirect
    assert_equal "Interview time slot has been updated.", flash[:notice]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.scheduled?
    end
  end

  test "hiring manager can schedule even without being on panel" do
    create_interview_with_participant!(@interviewer_user)
    sign_in @hiring_manager

    scheduled_time = 3.days.from_now.change(usec: 0)
    patch schedule_path, params: { scheduled_at: scheduled_time.iso8601 }

    assert_response :redirect
    assert_equal "Interview time slot has been updated.", flash[:notice]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.scheduled?
    end
  end

  test "unauthenticated user cannot schedule" do
    create_interview_with_participant!(@interviewer_user)

    patch schedule_path, params: { scheduled_at: 2.days.from_now.iso8601 }

    assert_response :redirect
    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.unscheduled?
    end
  end

  test "scheduling with blank time shows error" do
    create_interview_with_participant!(@interviewer_user)
    sign_in @interviewer_user

    patch schedule_path, params: { scheduled_at: "" }

    assert_response :redirect
    assert_equal "Please provide a date and time for the interview.", flash[:alert]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.unscheduled?
    end
  end

  test "second panel member can also update the time slot" do
    create_interview_with_participant!(@interviewer_user)

    second_interviewer = ActsAsTenant.with_tenant(@company) do
      user = User.create!(
        company: @company,
        email: "second@testcorp.com",
        first_name: "Second",
        last_name: "Interviewer",
        role: "interviewer"
      )
      @interview.assign_interviewer!(user)
      user
    end

    sign_in second_interviewer

    scheduled_time = 4.days.from_now.change(usec: 0)
    patch schedule_path, params: { scheduled_at: scheduled_time.iso8601 }

    assert_response :redirect
    assert_equal "Interview time slot has been updated.", flash[:notice]

    ActsAsTenant.with_tenant(@company) do
      @interview.reload
      assert @interview.scheduled?
      assert_in_delta scheduled_time.to_i, @interview.scheduled_at.to_i, 1
    end
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "cannot access applications from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      other_admin = User.create!(
        company: other_company,
        email: "admin@othercorp.com",
        first_name: "Other",
        last_name: "Admin",
        role: "admin"
      )

      other_candidate = Candidate.create!(
        company: other_company,
        first_name: "Other",
        last_name: "Candidate",
        email: "oc@example.com"
      )
      other_role = Role.create!(company: other_company, title: "Other Role")
      other_app = ApplicationSubmission.create!(
        company: other_company,
        candidate: other_candidate,
        role: other_role
      )

      # Verify othercorp admin can't see testcorp's application via acts_as_tenant
      assert_raises(ActiveRecord::RecordNotFound) do
        ApplicationSubmission.find(@application.id)
      end

      # And testcorp can't see othercorp's
      ActsAsTenant.with_tenant(@company) do
        assert_raises(ActiveRecord::RecordNotFound) do
          ApplicationSubmission.find(other_app.id)
        end
      end
    end
  end
end
