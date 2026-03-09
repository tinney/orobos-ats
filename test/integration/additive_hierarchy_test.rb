# frozen_string_literal: true

require "test_helper"

# Comprehensive integration test for the three-tier ADDITIVE permission hierarchy.
#
# Verifies the superset property across all endpoint tiers:
#   1. Admin-only endpoints (user management): Admin ✓, HM ✗, Interviewer ✗
#   2. HM-level endpoints (roles, applications, interviews, offers, phases, questions):
#      Admin ✓, HM ✓, Interviewer ✗
#   3. Interviewer-level endpoints (dashboard, my_interviews, scorecards):
#      Admin ✓, HM ✓, Interviewer ✓
#
# This proves:
#   - Admin can do everything HM can do
#   - HM can do everything Interviewer can do
#   - Interviewer cannot perform HM-only or Admin-only actions
class AdditiveHierarchyTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Additive Corp", subdomain: "additive")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company, email: "admin@additive.com",
        first_name: "Ada", last_name: "Admin", role: "admin"
      )
      @hm = User.create!(
        company: @company, email: "hm@additive.com",
        first_name: "Hannah", last_name: "Manager", role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company, email: "iv@additive.com",
        first_name: "Ivan", last_name: "Viewer", role: "interviewer"
      )
      @target_user = User.create!(
        company: @company, email: "target@additive.com",
        first_name: "Tina", last_name: "Target", role: "interviewer"
      )

      # Create a role for testing HM-level endpoints
      # Note: Role#after_create seeds default interview phases automatically
      @role = Role.create!(
        company: @company, title: "Software Engineer",
        status: "draft", location: "Remote"
      )

      # Use the first default phase seeded by the Role callback
      @phase = @role.interview_phases.active.ordered.first

      # Create a candidate and application
      @candidate = Candidate.create!(
        company: @company, email: "candidate@example.com",
        first_name: "Charlie", last_name: "Candidate"
      )
      @application = ApplicationSubmission.create!(
        company: @company, candidate: @candidate,
        role: @role, status: "applied"
      )

      # Create an interview for the application
      @interview = Interview.create!(
        company: @company, application: @application,
        interview_phase: @phase, status: "unscheduled"
      )

      # Assign the interviewer as a panel member
      InterviewParticipant.create!(
        interview: @interview, user: @interviewer
      )

      # Second role for transfer testing
      @other_role = Role.create!(
        company: @company, title: "Product Manager",
        status: "draft", location: "NYC"
      )
    end

    host! "additive.example.com"
  end

  # --- Helpers ---

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  def sign_out_user
    delete logout_path
    reset!
    host! "additive.example.com"
  end

  # =====================================================
  # TIER 1: Admin-only endpoints (user management)
  # Admin ✓, HM ✗, Interviewer ✗
  # =====================================================

  test "admin can access admin-only user management" do
    sign_in(@admin)

    get admin_users_path
    assert_response :success, "Admin should access user list"

    get new_admin_user_path
    assert_response :success, "Admin should access new user form"

    get edit_admin_user_path(@target_user)
    assert_response :success, "Admin should access edit user form"
  end

  test "hiring_manager cannot access admin-only user management" do
    sign_in(@hm)

    get admin_users_path
    assert_redirected_to tenant_root_path, "HM should be denied user list"

    get new_admin_user_path
    assert_redirected_to tenant_root_path, "HM should be denied new user form"

    post admin_users_path, params: {
      user: {email: "denied@additive.com", first_name: "D", last_name: "D", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path, "HM should be denied user creation"

    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path, "HM should be denied user promotion"

    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path, "HM should be denied user deactivation"
  end

  test "interviewer cannot access admin-only user management" do
    sign_in(@interviewer)

    get admin_users_path
    assert_redirected_to tenant_root_path, "Interviewer should be denied user list"

    post admin_users_path, params: {
      user: {email: "denied@additive.com", first_name: "D", last_name: "D", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path, "Interviewer should be denied user creation"

    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path, "Interviewer should be denied user promotion"
  end

  # =====================================================
  # TIER 2: HM-level endpoints
  # Admin ✓, HM ✓, Interviewer ✗
  # =====================================================

  # --- Roles Controller (HM-level) ---

  test "admin can access HM-level roles endpoints" do
    sign_in(@admin)

    get admin_roles_path
    assert_response :success, "Admin should access roles list"

    get new_admin_role_path
    assert_response :success, "Admin should access new role form"

    get admin_role_path(@role)
    assert_response :success, "Admin should access role detail"

    get edit_admin_role_path(@role)
    assert_response :success, "Admin should access edit role form"
  end

  test "hiring_manager can access HM-level roles endpoints" do
    sign_in(@hm)

    get admin_roles_path
    assert_response :success, "HM should access roles list"

    get new_admin_role_path
    assert_response :success, "HM should access new role form"

    get admin_role_path(@role)
    assert_response :success, "HM should access role detail"

    get edit_admin_role_path(@role)
    assert_response :success, "HM should access edit role form"

    post admin_roles_path, params: {
      role: {title: "HM Created Role", location: "NYC"}
    }
    assert_response :redirect, "HM should create roles"
  end

  test "interviewer is denied HM-level roles endpoints" do
    sign_in(@interviewer)

    get admin_roles_path
    assert_redirected_to tenant_root_path, "Interviewer should be denied roles list"

    get new_admin_role_path
    assert_redirected_to tenant_root_path, "Interviewer should be denied new role form"

    get admin_role_path(@role)
    assert_redirected_to tenant_root_path, "Interviewer should be denied role detail"

    post admin_roles_path, params: {
      role: {title: "Should Fail", location: "NYC"}
    }
    assert_redirected_to tenant_root_path, "Interviewer should be denied role creation"
  end

  # --- Applications Controller (HM-level) ---

  test "admin can access HM-level applications endpoints" do
    sign_in(@admin)

    get admin_role_applications_path(@role)
    assert_response :success, "Admin should access applications list"

    get admin_application_path(@application)
    assert_response :success, "Admin should access application detail"
  end

  test "hiring_manager can access HM-level applications endpoints" do
    sign_in(@hm)

    get admin_role_applications_path(@role)
    assert_response :success, "HM should access applications list"

    get admin_application_path(@application)
    assert_response :success, "HM should access application detail"
  end

  test "interviewer is denied HM-level applications endpoints" do
    sign_in(@interviewer)

    get admin_role_applications_path(@role)
    assert_redirected_to tenant_root_path, "Interviewer should be denied applications list"

    get admin_application_path(@application)
    assert_redirected_to tenant_root_path, "Interviewer should be denied application detail"
  end

  # --- Application transitions (HM-level) ---

  test "admin can transition applications" do
    sign_in(@admin)

    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to admin_application_path(@application)
    @application.reload
    assert_equal "interviewing", @application.status
  end

  test "hiring_manager can transition applications" do
    sign_in(@hm)

    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to admin_application_path(@application)
    @application.reload
    assert_equal "interviewing", @application.status
  end

  test "interviewer is denied application transitions" do
    sign_in(@interviewer)

    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to tenant_root_path
    @application.reload
    assert_equal "applied", @application.status, "Application status should remain unchanged"
  end

  # --- Application destruction (Admin-only within applications controller) ---

  test "admin can destroy applications" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ApplicationSubmission.count } }, -1 do
      delete admin_application_path(@application)
    end
    assert_redirected_to admin_roles_path
  end

  test "hiring_manager is denied application destruction (admin-only action)" do
    sign_in(@hm)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ApplicationSubmission.count } } do
      delete admin_application_path(@application)
    end
    assert_redirected_to tenant_root_path, "HM should be denied destroy (admin-only)"
  end

  test "interviewer is denied application destruction" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ApplicationSubmission.count } } do
      delete admin_application_path(@application)
    end
    assert_redirected_to tenant_root_path
  end

  # --- Interviews Controller: assign (HM-level) ---

  test "admin can assign interviewers" do
    sign_in(@admin)

    post assign_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {user_id: @hm.id}

    assert_response :redirect
    assert_not_equal tenant_root_path, response.location.split("additive.example.com").last
  end

  test "hiring_manager can assign interviewers" do
    sign_in(@hm)

    # Create a fresh user to assign
    new_user = ActsAsTenant.with_tenant(@company) do
      User.create!(
        company: @company, email: "assign-target@additive.com",
        first_name: "Assign", last_name: "Target", role: "interviewer"
      )
    end

    post assign_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {user_id: new_user.id}

    assert_response :redirect
  end

  test "interviewer is denied assigning interviewers" do
    sign_in(@interviewer)

    post assign_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {user_id: @target_user.id}

    assert_redirected_to tenant_root_path
  end

  # --- Interviews Controller: complete and cancel (HM-level) ---

  test "admin can complete interviews" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @interview.update!(status: "scheduled", scheduled_at: 1.day.from_now) }

    patch complete_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
    assert_response :redirect
    @interview.reload
    assert_equal "complete", @interview.status
  end

  test "hiring_manager can complete interviews" do
    sign_in(@hm)
    ActsAsTenant.with_tenant(@company) { @interview.update!(status: "scheduled", scheduled_at: 1.day.from_now) }

    patch complete_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
    assert_response :redirect
    @interview.reload
    assert_equal "complete", @interview.status
  end

  test "interviewer is denied completing interviews" do
    sign_in(@interviewer)
    ActsAsTenant.with_tenant(@company) { @interview.update!(status: "scheduled", scheduled_at: 1.day.from_now) }

    patch complete_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
    assert_redirected_to tenant_root_path
    @interview.reload
    assert_equal "scheduled", @interview.status
  end

  test "admin can cancel interviews" do
    sign_in(@admin)

    patch cancel_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
    assert_response :redirect
    @interview.reload
    assert_equal "cancelled", @interview.status
  end

  test "interviewer is denied cancelling interviews" do
    sign_in(@interviewer)

    patch cancel_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    )
    assert_redirected_to tenant_root_path
    @interview.reload
    assert_equal "unscheduled", @interview.status
  end

  # --- Interview Phases Controller (HM-level) ---

  test "admin can create interview phases" do
    sign_in(@admin)

    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Admin Phase"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "hiring_manager can create interview phases" do
    sign_in(@hm)

    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "HM Phase"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "interviewer is denied creating interview phases" do
    sign_in(@interviewer)

    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Should Fail"}
    }
    assert_redirected_to tenant_root_path
  end

  # --- Custom Questions Controller (HM-level) ---

  test "admin can create custom questions" do
    sign_in(@admin)

    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "Admin Q", field_type: "text"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "hiring_manager can create custom questions" do
    sign_in(@hm)

    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "HM Q", field_type: "text"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "interviewer is denied creating custom questions" do
    sign_in(@interviewer)

    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "Should Fail", field_type: "text"}
    }
    assert_redirected_to tenant_root_path
  end

  # --- Offers Controller (HM-level) ---

  test "admin can create offers" do
    sign_in(@admin)

    post admin_application_offers_path(@application), params: {
      offer: {salary: 100000, salary_currency: "USD", start_date: 30.days.from_now.to_date, status: "pending"}
    }
    assert_redirected_to admin_application_path(@application)
  end

  test "hiring_manager can create offers" do
    sign_in(@hm)

    post admin_application_offers_path(@application), params: {
      offer: {salary: 100000, salary_currency: "USD", start_date: 30.days.from_now.to_date, status: "pending"}
    }
    assert_redirected_to admin_application_path(@application)
  end

  test "interviewer is denied creating offers" do
    sign_in(@interviewer)

    post admin_application_offers_path(@application), params: {
      offer: {salary: 100000, salary_currency: "USD", start_date: 30.days.from_now.to_date, status: "pending"}
    }
    assert_redirected_to tenant_root_path
  end

  # =====================================================
  # TIER 3: Interviewer-level endpoints
  # Admin ✓, HM ✓, Interviewer ✓
  # =====================================================

  # --- Dashboard (Interviewer-level) ---

  test "admin can access interviewer-level dashboard" do
    sign_in(@admin)
    get admin_dashboard_path
    assert_response :success, "Admin should access dashboard"
  end

  test "hiring_manager can access interviewer-level dashboard" do
    sign_in(@hm)
    get admin_dashboard_path
    assert_response :success, "HM should access dashboard"
  end

  test "interviewer can access interviewer-level dashboard" do
    sign_in(@interviewer)
    get admin_dashboard_path
    assert_response :success, "Interviewer should access dashboard"
  end

  # --- My Interviews (Interviewer-level) ---

  test "admin can access my interviews" do
    sign_in(@admin)
    get admin_my_interviews_path
    assert_response :success, "Admin should access my interviews"
  end

  test "hiring_manager can access my interviews" do
    sign_in(@hm)
    get admin_my_interviews_path
    assert_response :success, "HM should access my interviews"
  end

  test "interviewer can access my interviews" do
    sign_in(@interviewer)
    get admin_my_interviews_path
    assert_response :success, "Interviewer should access my interviews"
  end

  # --- Scorecards: new/create (Interviewer-level) ---

  test "admin can access scorecard form" do
    sign_in(@admin)
    get new_admin_interview_scorecard_path(@interview)
    assert_response :success, "Admin should access scorecard form"
  end

  test "hiring_manager can access scorecard form" do
    sign_in(@hm)
    get new_admin_interview_scorecard_path(@interview)
    assert_response :success, "HM should access scorecard form"
  end

  test "interviewer can access scorecard form" do
    sign_in(@interviewer)
    get new_admin_interview_scorecard_path(@interview)
    assert_response :success, "Interviewer should access scorecard form"
  end

  test "interviewer can create a scorecard" do
    sign_in(@interviewer)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { Scorecard.count } }, 1 do
      post admin_interview_scorecards_path(@interview), params: {
        scorecard: {
          notes: "Great candidate",
          scorecard_categories_attributes: {
            "0" => {name: "Technical", rating: 4}
          }
        }
      }
    end
    assert_response :redirect
  end

  # --- Interview scheduling (Interviewer with panel membership) ---

  test "interviewer who is panel member can schedule interviews" do
    sign_in(@interviewer)

    patch schedule_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {scheduled_at: 2.days.from_now.iso8601}

    assert_response :redirect
    @interview.reload
    assert_equal "scheduled", @interview.status
  end

  test "admin can schedule interviews without being panel member" do
    sign_in(@admin)

    patch schedule_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {scheduled_at: 2.days.from_now.iso8601}

    assert_response :redirect
    @interview.reload
    assert_equal "scheduled", @interview.status
  end

  test "hiring_manager can schedule interviews without being panel member" do
    sign_in(@hm)

    patch schedule_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {scheduled_at: 2.days.from_now.iso8601}

    assert_response :redirect
    @interview.reload
    assert_equal "scheduled", @interview.status
  end

  test "interviewer who is NOT panel member is denied scheduling" do
    # Create a non-panel interviewer
    other_interviewer = ActsAsTenant.with_tenant(@company) do
      User.create!(
        company: @company, email: "other-iv@additive.com",
        first_name: "Other", last_name: "Viewer", role: "interviewer"
      )
    end
    sign_in(other_interviewer)

    patch schedule_admin_application_interview_phase_interview_path(
      application_id: @application.id,
      interview_phase_id: @phase.id
    ), params: {scheduled_at: 2.days.from_now.iso8601}

    # Should be denied by require_panel_member
    assert_response :redirect
    @interview.reload
    assert_equal "unscheduled", @interview.status
  end

  # =====================================================
  # CROSS-TIER CONSISTENCY
  # Proves the additive superset property
  # =====================================================

  test "admin can access all three tiers of endpoints" do
    sign_in(@admin)

    # Tier 1: Admin-only
    get admin_users_path
    assert_response :success

    # Tier 2: HM-level
    get admin_roles_path
    assert_response :success

    get admin_role_applications_path(@role)
    assert_response :success

    # Tier 3: Interviewer-level
    get admin_dashboard_path
    assert_response :success

    get admin_my_interviews_path
    assert_response :success
  end

  test "hiring_manager can access tier 2 and tier 3 but not tier 1" do
    sign_in(@hm)

    # Tier 1: Admin-only — DENIED
    get admin_users_path
    assert_redirected_to tenant_root_path

    # Tier 2: HM-level — ALLOWED
    get admin_roles_path
    assert_response :success

    get admin_role_applications_path(@role)
    assert_response :success

    # Tier 3: Interviewer-level — ALLOWED
    get admin_dashboard_path
    assert_response :success

    get admin_my_interviews_path
    assert_response :success
  end

  test "interviewer can access tier 3 but not tier 1 or tier 2" do
    sign_in(@interviewer)

    # Tier 1: Admin-only — DENIED
    get admin_users_path
    assert_redirected_to tenant_root_path

    # Tier 2: HM-level — DENIED
    get admin_roles_path
    assert_redirected_to tenant_root_path

    get admin_role_applications_path(@role)
    assert_redirected_to tenant_root_path

    # Tier 3: Interviewer-level — ALLOWED
    get admin_dashboard_path
    assert_response :success

    get admin_my_interviews_path
    assert_response :success
  end

  # =====================================================
  # Unauthenticated users denied at all tiers
  # =====================================================

  test "unauthenticated user is denied all three tiers" do
    # Tier 1
    get admin_users_path
    assert_response :redirect

    # Tier 2
    get admin_roles_path
    assert_response :redirect

    get admin_role_applications_path(@role)
    assert_response :redirect

    # Tier 3
    get admin_dashboard_path
    assert_response :redirect

    get admin_my_interviews_path
    assert_response :redirect
  end
end
