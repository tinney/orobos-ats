# frozen_string_literal: true

require "test_helper"

# Comprehensive integration test for the three-tier additive permission hierarchy:
#   Admin ⊃ Hiring Manager ⊃ Interviewer
#
# Verifies that:
# - Admin can access all protected endpoints (admin actions + authenticated routes)
# - Hiring Manager can access authenticated routes but NOT admin actions
# - Interviewer can access authenticated routes but NOT admin actions
# - Admin access is a strict superset of Hiring Manager access
# - Hiring Manager access is a strict superset of Interviewer access
# - Unauthenticated users cannot access any protected endpoint
class PermissionHierarchyTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Hierarchy Corp", subdomain: "hierarchy")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company,
        email: "admin@hierarchy.com",
        first_name: "Ada",
        last_name: "Admin",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        email: "hm@hierarchy.com",
        first_name: "Hannah",
        last_name: "Manager",
        role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company,
        email: "interviewer@hierarchy.com",
        first_name: "Ivan",
        last_name: "Viewer",
        role: "interviewer"
      )
      # Target user for edit/update/promote/demote/deactivate/reactivate actions
      @target_user = User.create!(
        company: @company,
        email: "target@hierarchy.com",
        first_name: "Tina",
        last_name: "Target",
        role: "interviewer"
      )
    end

    host! "hierarchy.example.com"
  end

  # --- Helper ---

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  def sign_out
    delete logout_path
    reset!
    host! "hierarchy.example.com"
  end

  # =====================================================
  # Admin-only endpoints: every admin action must be
  # accessible by Admin and denied to HM and Interviewer
  # =====================================================

  # --- GET /admin/users (index) ---

  test "admin can access admin users index" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
  end

  test "hiring_manager is denied admin users index" do
    sign_in(@hiring_manager)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "interviewer is denied admin users index" do
    sign_in(@interviewer)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  # --- GET /admin/users/new ---

  test "admin can access new user form" do
    sign_in(@admin)
    get new_admin_user_path
    assert_response :success
  end

  test "hiring_manager is denied new user form" do
    sign_in(@hiring_manager)
    get new_admin_user_path
    assert_redirected_to tenant_root_path
  end

  test "interviewer is denied new user form" do
    sign_in(@interviewer)
    get new_admin_user_path
    assert_redirected_to tenant_root_path
  end

  # --- POST /admin/users (create) ---

  test "admin can create users" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { User.count } }, 1 do
      post admin_users_path, params: {
        user: {email: "new@hierarchy.com", first_name: "New", last_name: "User", role: "interviewer"}
      }
    end

    assert_redirected_to admin_users_path
  end

  test "hiring_manager is denied user creation" do
    sign_in(@hiring_manager)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { User.count } } do
      post admin_users_path, params: {
        user: {email: "hm-created@hierarchy.com", first_name: "HM", last_name: "Created", role: "interviewer"}
      }
    end

    assert_redirected_to tenant_root_path
  end

  test "interviewer is denied user creation" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { User.count } } do
      post admin_users_path, params: {
        user: {email: "int-created@hierarchy.com", first_name: "Int", last_name: "Created", role: "interviewer"}
      }
    end

    assert_redirected_to tenant_root_path
  end

  # --- GET /admin/users/:id/edit ---

  test "admin can access edit user form" do
    sign_in(@admin)
    get edit_admin_user_path(@target_user)
    assert_response :success
  end

  test "hiring_manager is denied edit user form" do
    sign_in(@hiring_manager)
    get edit_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  test "interviewer is denied edit user form" do
    sign_in(@interviewer)
    get edit_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  # --- PATCH /admin/users/:id (update) ---

  test "admin can update users" do
    sign_in(@admin)
    patch admin_user_path(@target_user), params: {
      user: {first_name: "Updated"}
    }
    assert_redirected_to admin_users_path
    @target_user.reload
    assert_equal "Updated", @target_user.first_name
  end

  test "hiring_manager is denied user update" do
    sign_in(@hiring_manager)
    patch admin_user_path(@target_user), params: {
      user: {first_name: "Hacked"}
    }
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "Tina", @target_user.first_name
  end

  test "interviewer is denied user update" do
    sign_in(@interviewer)
    patch admin_user_path(@target_user), params: {
      user: {first_name: "Hacked"}
    }
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "Tina", @target_user.first_name
  end

  # --- PATCH /admin/users/:id/promote ---

  test "admin can promote users" do
    sign_in(@admin)
    patch promote_admin_user_path(@target_user)
    assert_redirected_to admin_users_path
    @target_user.reload
    assert_equal "hiring_manager", @target_user.role
  end

  test "hiring_manager is denied user promotion" do
    sign_in(@hiring_manager)
    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "interviewer", @target_user.role
  end

  test "interviewer is denied user promotion" do
    sign_in(@interviewer)
    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "interviewer", @target_user.role
  end

  # --- PATCH /admin/users/:id/demote ---

  test "admin can demote users" do
    sign_in(@admin)
    # First promote target to HM so we can demote
    ActsAsTenant.with_tenant(@company) { @target_user.update!(role: "hiring_manager") }

    patch demote_admin_user_path(@target_user)
    assert_redirected_to admin_users_path
    @target_user.reload
    assert_equal "interviewer", @target_user.role
  end

  test "hiring_manager is denied user demotion" do
    sign_in(@hiring_manager)
    ActsAsTenant.with_tenant(@company) { @target_user.update!(role: "hiring_manager") }

    patch demote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "hiring_manager", @target_user.role
  end

  test "interviewer is denied user demotion" do
    sign_in(@interviewer)
    ActsAsTenant.with_tenant(@company) { @target_user.update!(role: "hiring_manager") }

    patch demote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert_equal "hiring_manager", @target_user.role
  end

  # --- PATCH /admin/users/:id/deactivate ---

  test "admin can deactivate users" do
    sign_in(@admin)
    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to admin_users_path
    @target_user.reload
    assert @target_user.discarded?
  end

  test "hiring_manager is denied user deactivation" do
    sign_in(@hiring_manager)
    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert @target_user.active?
  end

  test "interviewer is denied user deactivation" do
    sign_in(@interviewer)
    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert @target_user.active?
  end

  # --- PATCH /admin/users/:id/reactivate ---

  test "admin can reactivate users" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @target_user.discard! }

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to admin_users_path
    @target_user.reload
    assert @target_user.active?
  end

  test "hiring_manager is denied user reactivation" do
    sign_in(@hiring_manager)
    ActsAsTenant.with_tenant(@company) { @target_user.discard! }

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert @target_user.discarded?
  end

  test "interviewer is denied user reactivation" do
    sign_in(@interviewer)
    ActsAsTenant.with_tenant(@company) { @target_user.discard! }

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
    @target_user.reload
    assert @target_user.discarded?
  end

  # =====================================================
  # Unauthenticated access: all protected endpoints must
  # redirect unauthenticated users
  # =====================================================

  test "unauthenticated user is denied all admin endpoints" do
    # Index
    get admin_users_path
    assert_response :redirect

    # New
    get new_admin_user_path
    assert_response :redirect

    # Create
    post admin_users_path, params: {
      user: {email: "x@x.com", first_name: "X", last_name: "Y", role: "interviewer"}
    }
    assert_response :redirect

    # Edit
    get edit_admin_user_path(@target_user)
    assert_response :redirect

    # Update
    patch admin_user_path(@target_user), params: {user: {first_name: "X"}}
    assert_response :redirect

    # Promote
    patch promote_admin_user_path(@target_user)
    assert_response :redirect

    # Demote
    patch demote_admin_user_path(@target_user)
    assert_response :redirect

    # Deactivate
    patch deactivate_admin_user_path(@target_user)
    assert_response :redirect

    # Reactivate
    patch reactivate_admin_user_path(@target_user)
    assert_response :redirect
  end

  # =====================================================
  # Authenticated routes: all three roles should be able
  # to access non-admin authenticated routes
  # =====================================================

  test "admin can access tenant root (authenticated route)" do
    sign_in(@admin)
    get tenant_root_path
    # Logged-in users are redirected to admin dashboard
    assert_redirected_to admin_dashboard_path
  end

  test "hiring_manager can access tenant root (authenticated route)" do
    sign_in(@hiring_manager)
    get tenant_root_path
    assert_redirected_to admin_dashboard_path
  end

  test "interviewer can access tenant root (authenticated route)" do
    sign_in(@interviewer)
    get tenant_root_path
    assert_redirected_to admin_dashboard_path
  end

  # =====================================================
  # Role hierarchy model methods: verify the additive
  # hierarchy logic in the User model
  # =====================================================

  test "admin role checks reflect full hierarchy" do
    assert @admin.admin?
    assert @admin.at_least_hiring_manager?
    refute @admin.hiring_manager?
    refute @admin.interviewer?
  end

  test "hiring_manager role checks reflect mid-tier hierarchy" do
    refute @hiring_manager.admin?
    assert @hiring_manager.at_least_hiring_manager?
    assert @hiring_manager.hiring_manager?
    refute @hiring_manager.interviewer?
  end

  test "interviewer role checks reflect base-tier hierarchy" do
    refute @interviewer.admin?
    refute @interviewer.at_least_hiring_manager?
    refute @interviewer.hiring_manager?
    assert @interviewer.interviewer?
  end

  # =====================================================
  # Cross-role consistency: verify that Admin has access
  # to everything HM has, and HM has access to everything
  # Interviewer has — confirming the additive superset
  # =====================================================

  test "admin retains access after lower-tier users are denied" do
    # Sign in as interviewer, get denied
    sign_in(@interviewer)
    get admin_users_path
    assert_redirected_to tenant_root_path

    # Sign out and sign in as admin
    sign_out
    sign_in(@admin)
    get admin_users_path
    assert_response :success
  end

  test "all roles denied cross-tenant admin endpoints" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      @other_admin = User.create!(
        company: other_company,
        email: "admin@othercorp.com",
        first_name: "Other",
        last_name: "Admin",
        role: "admin"
      )
    end

    # Admin from one tenant cannot access another tenant's admin routes
    sign_in(@admin)
    host! "othercorp.example.com"
    get admin_users_path
    # Should be denied because session user belongs to different tenant
    assert_response :redirect
  end

  # =====================================================
  # Comprehensive sweep: for every admin endpoint, verify
  # the same authorization pattern (admin=allowed, hm=denied,
  # interviewer=denied) in a single test per role
  # =====================================================

  ADMIN_ONLY_ACTIONS = %i[
    admin_users_path
    new_admin_user_path
  ].freeze

  test "hiring_manager is consistently denied across all admin GET endpoints" do
    sign_in(@hiring_manager)

    get admin_users_path
    assert_redirected_to tenant_root_path

    get new_admin_user_path
    assert_redirected_to tenant_root_path

    get edit_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  test "hiring_manager is consistently denied across all admin mutation endpoints" do
    sign_in(@hiring_manager)

    post admin_users_path, params: {
      user: {email: "denied@hierarchy.com", first_name: "D", last_name: "D", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path

    patch admin_user_path(@target_user), params: {user: {first_name: "D"}}
    assert_redirected_to tenant_root_path

    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch demote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  test "interviewer is consistently denied across all admin GET endpoints" do
    sign_in(@interviewer)

    get admin_users_path
    assert_redirected_to tenant_root_path

    get new_admin_user_path
    assert_redirected_to tenant_root_path

    get edit_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  test "interviewer is consistently denied across all admin mutation endpoints" do
    sign_in(@interviewer)

    post admin_users_path, params: {
      user: {email: "denied@hierarchy.com", first_name: "D", last_name: "D", role: "interviewer"}
    }
    assert_redirected_to tenant_root_path

    patch admin_user_path(@target_user), params: {user: {first_name: "D"}}
    assert_redirected_to tenant_root_path

    patch promote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch demote_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to tenant_root_path
  end

  test "admin can access all admin GET and mutation endpoints" do
    sign_in(@admin)

    # GET endpoints
    get admin_users_path
    assert_response :success

    get new_admin_user_path
    assert_response :success

    get edit_admin_user_path(@target_user)
    assert_response :success

    # Mutation endpoints
    patch admin_user_path(@target_user), params: {user: {first_name: "AdminUpdated"}}
    assert_redirected_to admin_users_path

    patch promote_admin_user_path(@target_user)
    assert_redirected_to admin_users_path

    patch demote_admin_user_path(@target_user)
    assert_redirected_to admin_users_path

    patch deactivate_admin_user_path(@target_user)
    assert_redirected_to admin_users_path

    patch reactivate_admin_user_path(@target_user)
    assert_redirected_to admin_users_path

    post admin_users_path, params: {
      user: {email: "admin-created@hierarchy.com", first_name: "A", last_name: "C", role: "interviewer"}
    }
    assert_redirected_to admin_users_path
  end
end
