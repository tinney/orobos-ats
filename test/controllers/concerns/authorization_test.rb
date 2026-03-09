# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Auth Corp", subdomain: "authcorp")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company,
        email: "admin@authcorp.com",
        first_name: "Alice",
        last_name: "Admin",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        email: "hm@authcorp.com",
        first_name: "Harry",
        last_name: "Manager",
        role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company,
        email: "interviewer@authcorp.com",
        first_name: "Ivan",
        last_name: "Viewer",
        role: "interviewer"
      )

      @role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "published"
      )
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
        status: "applied",
        submitted_at: Time.current
      )
    end

    host! "authcorp.example.com"
  end

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  # ==========================================
  # Admin-only routes (user management)
  # ==========================================

  test "admin can access admin-only routes" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
  end

  test "hiring_manager cannot access admin-only routes" do
    sign_in(@hiring_manager)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "interviewer cannot access admin-only routes" do
    sign_in(@interviewer)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "unauthenticated user is redirected before authorization check" do
    get admin_users_path
    assert_response :redirect
  end

  # ==========================================
  # User management — admin only
  # ==========================================

  test "admin can create users" do
    sign_in(@admin)
    post admin_users_path, params: {
      user: {email: "new@authcorp.com", first_name: "New", last_name: "User", role: "interviewer"}
    }
    assert_redirected_to admin_users_path
  end

  test "hiring_manager cannot create users" do
    sign_in(@hiring_manager)
    post admin_users_path, params: {
      user: {email: "new@authcorp.com", first_name: "New", last_name: "User", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path
  end

  test "interviewer cannot create users" do
    sign_in(@interviewer)
    post admin_users_path, params: {
      user: {email: "new@authcorp.com", first_name: "New", last_name: "User", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path
  end

  test "admin can promote users" do
    sign_in(@admin)
    patch promote_admin_user_path(@interviewer)
    assert_redirected_to admin_users_path
    @interviewer.reload
    assert_equal "hiring_manager", @interviewer.role
  end

  test "hiring_manager cannot promote users" do
    sign_in(@hiring_manager)
    patch promote_admin_user_path(@interviewer)
    assert_redirected_to tenant_root_path
    @interviewer.reload
    assert_equal "interviewer", @interviewer.role
  end

  test "admin can deactivate users" do
    sign_in(@admin)
    patch deactivate_admin_user_path(@interviewer)
    assert_redirected_to admin_users_path
    @interviewer.reload
    assert @interviewer.discarded?
  end

  test "interviewer cannot deactivate users" do
    sign_in(@interviewer)
    patch deactivate_admin_user_path(@hiring_manager)
    assert_redirected_to tenant_root_path
    @hiring_manager.reload
    assert @hiring_manager.active?
  end

  # ==========================================
  # Dashboard — accessible to all roles (interviewer+)
  # ==========================================

  test "admin can access dashboard" do
    sign_in(@admin)
    get admin_dashboard_path
    assert_response :success
  end

  test "hiring_manager can access dashboard" do
    sign_in(@hiring_manager)
    get admin_dashboard_path
    assert_response :success
  end

  test "interviewer can access dashboard" do
    sign_in(@interviewer)
    get admin_dashboard_path
    assert_response :success
  end

  # ==========================================
  # Roles — accessible to hiring_manager+
  # ==========================================

  test "admin can access roles index" do
    sign_in(@admin)
    get admin_roles_path
    assert_response :success
  end

  test "hiring_manager can access roles index" do
    sign_in(@hiring_manager)
    get admin_roles_path
    assert_response :success
  end

  test "interviewer cannot access roles index" do
    sign_in(@interviewer)
    get admin_roles_path
    assert_redirected_to tenant_root_path
  end

  test "admin can create roles" do
    sign_in(@admin)
    post admin_roles_path, params: {
      role: {title: "Product Manager", status: "draft"}
    }
    assert_redirected_to admin_roles_path
  end

  test "hiring_manager can create roles" do
    sign_in(@hiring_manager)
    post admin_roles_path, params: {
      role: {title: "Product Manager", status: "draft"}
    }
    assert_redirected_to admin_roles_path
  end

  test "interviewer cannot create roles" do
    sign_in(@interviewer)
    post admin_roles_path, params: {
      role: {title: "Product Manager", status: "draft"}
    }
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Applications — hiring_manager+ for most, admin for destroy
  # ==========================================

  test "admin can view application" do
    sign_in(@admin)
    get admin_application_path(@application)
    assert_response :success
  end

  test "hiring_manager can view application" do
    sign_in(@hiring_manager)
    get admin_application_path(@application)
    assert_response :success
  end

  test "interviewer cannot view application" do
    sign_in(@interviewer)
    get admin_application_path(@application)
    assert_redirected_to tenant_root_path
  end

  test "admin can destroy application" do
    sign_in(@admin)
    delete admin_application_path(@application)
    assert_redirected_to admin_roles_path
    ActsAsTenant.with_tenant(@company) do
      assert_not ApplicationSubmission.exists?(@application.id)
    end
  end

  test "hiring_manager cannot destroy application" do
    sign_in(@hiring_manager)
    delete admin_application_path(@application)
    assert_redirected_to tenant_root_path
    ActsAsTenant.with_tenant(@company) do
      assert ApplicationSubmission.exists?(@application.id)
    end
  end

  test "interviewer cannot destroy application" do
    sign_in(@interviewer)
    delete admin_application_path(@application)
    assert_redirected_to tenant_root_path
    ActsAsTenant.with_tenant(@company) do
      assert ApplicationSubmission.exists?(@application.id)
    end
  end

  test "admin can transition application" do
    sign_in(@admin)
    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to admin_application_path(@application)
    @application.reload
    assert_equal "interviewing", @application.status
  end

  test "hiring_manager can transition application" do
    sign_in(@hiring_manager)
    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to admin_application_path(@application)
    @application.reload
    assert_equal "interviewing", @application.status
  end

  test "interviewer cannot transition application" do
    sign_in(@interviewer)
    patch transition_admin_application_path(@application), params: {status: "interviewing"}
    assert_redirected_to tenant_root_path
    @application.reload
    assert_equal "applied", @application.status
  end

  # ==========================================
  # My Interviews — accessible to all roles (interviewer+)
  # ==========================================

  test "admin can access my interviews" do
    sign_in(@admin)
    get admin_my_interviews_path
    assert_response :success
  end

  test "hiring_manager can access my interviews" do
    sign_in(@hiring_manager)
    get admin_my_interviews_path
    assert_response :success
  end

  test "interviewer can access my interviews" do
    sign_in(@interviewer)
    get admin_my_interviews_path
    assert_response :success
  end

  # ==========================================
  # Offers — hiring_manager+
  # ==========================================

  test "admin can create offer" do
    sign_in(@admin)
    post admin_application_offers_path(@application), params: {
      offer: {salary: 100_000, salary_currency: "USD", start_date: 1.month.from_now.to_date, status: "draft"}
    }
    assert_response :redirect
    refute_redirected_to_authorization_denied
  end

  test "hiring_manager can create offer" do
    sign_in(@hiring_manager)
    post admin_application_offers_path(@application), params: {
      offer: {salary: 100_000, salary_currency: "USD", start_date: 1.month.from_now.to_date, status: "draft"}
    }
    assert_response :redirect
    refute_redirected_to_authorization_denied
  end

  test "interviewer cannot create offer" do
    sign_in(@interviewer)
    post admin_application_offers_path(@application), params: {
      offer: {salary: 100_000, salary_currency: "USD", start_date: 1.month.from_now.to_date, status: "draft"}
    }
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Interview Phases — hiring_manager+
  # ==========================================

  test "admin can create interview phase" do
    sign_in(@admin)
    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Culture Fit"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "hiring_manager can create interview phase" do
    sign_in(@hiring_manager)
    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Culture Fit"}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "interviewer cannot create interview phase" do
    sign_in(@interviewer)
    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Culture Fit"}
    }
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Custom Questions — hiring_manager+
  # ==========================================

  test "admin can create custom question" do
    sign_in(@admin)
    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "Why us?", field_type: "text", required: true}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "hiring_manager can create custom question" do
    sign_in(@hiring_manager)
    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "Why us?", field_type: "text", required: true}
    }
    assert_redirected_to admin_role_path(@role)
  end

  test "interviewer cannot create custom question" do
    sign_in(@interviewer)
    post admin_role_custom_questions_path(@role), params: {
      custom_question: {label: "Why us?", field_type: "text", required: true}
    }
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Full hierarchy inheritance test
  # ==========================================

  test "admin inherits all hiring_manager and interviewer permissions" do
    sign_in(@admin)
    # Admin-level
    get admin_users_path
    assert_response :success
    # Hiring manager level
    get admin_roles_path
    assert_response :success
    get admin_application_path(@application)
    assert_response :success
    # Interviewer level
    get admin_dashboard_path
    assert_response :success
    get admin_my_interviews_path
    assert_response :success
  end

  test "hiring_manager inherits interviewer permissions but not admin" do
    sign_in(@hiring_manager)
    # Hiring manager level
    get admin_roles_path
    assert_response :success
    get admin_application_path(@application)
    assert_response :success
    # Interviewer level
    get admin_dashboard_path
    assert_response :success
    get admin_my_interviews_path
    assert_response :success
    # Admin level — denied
    get admin_users_path
    assert_redirected_to tenant_root_path
  end

  test "interviewer can only access interviewer-level actions" do
    sign_in(@interviewer)
    # Interviewer level
    get admin_dashboard_path
    assert_response :success
    get admin_my_interviews_path
    assert_response :success
    # Hiring manager level — denied
    get admin_roles_path
    assert_redirected_to tenant_root_path
    get admin_application_path(@application)
    assert_redirected_to tenant_root_path
    # Admin level — denied
    get admin_users_path
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Deactivated users cannot access anything
  # ==========================================

  test "deactivated user cannot access any admin routes" do
    sign_in(@interviewer)
    get admin_dashboard_path
    assert_response :success

    # Deactivate the user
    ActsAsTenant.with_tenant(@company) { @interviewer.discard! }

    # Deactivated user's session should be invalidated
    get admin_dashboard_path
    assert_response :redirect
  end

  # ==========================================
  # Cross-tenant isolation
  # ==========================================

  test "user from another tenant cannot access this tenant's admin" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_admin = ActsAsTenant.with_tenant(other_company) do
      User.create!(
        company: other_company,
        email: "admin@othercorp.com",
        first_name: "Bob",
        last_name: "Admin",
        role: "admin"
      )
    end

    # Sign in as admin on other tenant
    raw_token = ActsAsTenant.with_tenant(other_company) { other_admin.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)

    # Try to access authcorp's admin routes
    get admin_dashboard_path
    assert_response :redirect
  end

  private

  def refute_redirected_to_authorization_denied
    refute_equal tenant_root_url, response.location,
      "Expected NOT to be redirected to tenant_root (authorization denied)"
  end
end
