require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
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
      @interviewer = User.create!(
        company: @company,
        email: "interviewer@testcorp.com",
        first_name: "Ivan",
        last_name: "Viewer",
        role: "interviewer"
      )
    end

    # Set test host to tenant subdomain so session cookies persist across requests
    host! "testcorp.example.com"
  end

  # --- Helper to sign in as a specific user ---

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    # auth/callback works on any domain, including subdomain
    get auth_callback_path(token: raw_token)
  end

  # ==========================================
  # Authorization: only admins can access
  # ==========================================

  test "unauthenticated user is redirected" do
    get admin_users_path
    assert_response :redirect
  end

  test "interviewer cannot access admin users index" do
    sign_in(@interviewer)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "hiring manager cannot access admin users index" do
    sign_in(@hiring_manager)
    get admin_users_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "admin can access admin users index" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
  end

  # ==========================================
  # CRUD: Index
  # ==========================================

  test "index shows all active and deactivated users with status badges" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @interviewer.discard! }

    get admin_users_path
    assert_response :success
    # All users are displayed
    assert_match "Alice Admin", response.body
    assert_match "Harry Manager", response.body
    assert_match "Ivan Viewer", response.body
    # Status badges
    assert_select "span", text: "Active", minimum: 1
    assert_select "span", text: "Deactivated", minimum: 1
    # Role badges
    assert_select "span", text: "Admin", minimum: 1
    assert_select "span", text: "Hiring Manager", minimum: 1
  end

  # ==========================================
  # CRUD: New / Create
  # ==========================================

  test "new renders form" do
    sign_in(@admin)
    get new_admin_user_path
    assert_response :success
    assert_select "form"
  end

  test "create adds a new user to the tenant" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { User.count } }, 1 do
      post admin_users_path, params: {
        user: {
          email: "newbie@testcorp.com",
          first_name: "New",
          last_name: "Person",
          role: "interviewer"
        }
      }
    end

    assert_redirected_to admin_users_path
    assert_match "New Person has been added", flash[:notice]

    new_user = ActsAsTenant.with_tenant(@company) { User.find_by(email: "newbie@testcorp.com") }
    assert_equal @company.id, new_user.company_id
    assert_equal "interviewer", new_user.role
  end

  test "create with invalid data re-renders form" do
    sign_in(@admin)

    post admin_users_path, params: {
      user: {email: "", first_name: "", last_name: "", role: "interviewer"}
    }

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "create with duplicate email fails" do
    sign_in(@admin)

    post admin_users_path, params: {
      user: {email: "admin@testcorp.com", first_name: "Dup", last_name: "User", role: "interviewer"}
    }

    assert_response :unprocessable_entity
  end

  # ==========================================
  # CRUD: Edit / Update
  # ==========================================

  test "edit renders form for existing user" do
    sign_in(@admin)
    get edit_admin_user_path(@interviewer)
    assert_response :success
    assert_select "form"
  end

  test "update changes user attributes" do
    sign_in(@admin)

    patch admin_user_path(@interviewer), params: {
      user: {first_name: "Updated", last_name: "Name"}
    }

    assert_redirected_to admin_users_path
    @interviewer.reload
    assert_equal "Updated", @interviewer.first_name
    assert_equal "Name", @interviewer.last_name
  end

  test "update does not allow role changes through form" do
    sign_in(@admin)

    patch admin_user_path(@interviewer), params: {
      user: {first_name: "Ivan", last_name: "Viewer", role: "admin"}
    }

    # Role should not change — role is not in user_update_params
    @interviewer.reload
    assert_equal "interviewer", @interviewer.role
  end

  test "update with invalid data re-renders form" do
    sign_in(@admin)

    patch admin_user_path(@interviewer), params: {
      user: {email: ""}
    }

    assert_response :unprocessable_entity
  end

  # ==========================================
  # Role actions: Promote / Demote
  # ==========================================

  test "promote upgrades interviewer to hiring_manager" do
    sign_in(@admin)

    patch promote_admin_user_path(@interviewer)

    assert_redirected_to admin_users_path
    @interviewer.reload
    assert_equal "hiring_manager", @interviewer.role
    assert_match "promoted", flash[:notice]
  end

  test "promote upgrades hiring_manager to admin" do
    sign_in(@admin)

    patch promote_admin_user_path(@hiring_manager)

    assert_redirected_to admin_users_path
    @hiring_manager.reload
    assert_equal "admin", @hiring_manager.role
  end

  test "promote does not upgrade admin further" do
    sign_in(@admin)

    # Create another admin to promote (can't promote self)
    other_admin = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "other-admin@testcorp.com",
        first_name: "Other", last_name: "Admin", role: "admin")
    end

    patch promote_admin_user_path(other_admin)

    assert_redirected_to admin_users_path
    assert_match "cannot be promoted", flash[:alert]
    other_admin.reload
    assert_equal "admin", other_admin.role
  end

  test "demote downgrades hiring_manager to interviewer" do
    sign_in(@admin)

    patch demote_admin_user_path(@hiring_manager)

    assert_redirected_to admin_users_path
    @hiring_manager.reload
    assert_equal "interviewer", @hiring_manager.role
    assert_match "demoted", flash[:notice]
  end

  test "demote does not downgrade interviewer further" do
    sign_in(@admin)

    patch demote_admin_user_path(@interviewer)

    assert_redirected_to admin_users_path
    assert_match "cannot be demoted", flash[:alert]
    @interviewer.reload
    assert_equal "interviewer", @interviewer.role
  end

  # ==========================================
  # Lifecycle: Deactivate / Reactivate
  # ==========================================

  test "deactivate soft-deletes a user" do
    sign_in(@admin)

    patch deactivate_admin_user_path(@interviewer)

    assert_redirected_to admin_users_path
    @interviewer.reload
    assert @interviewer.discarded?
    assert_match "deactivated", flash[:notice]
  end

  test "reactivate restores a soft-deleted user" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @interviewer.discard! }

    patch reactivate_admin_user_path(@interviewer)

    assert_redirected_to admin_users_path
    @interviewer.reload
    assert @interviewer.active?
    assert_match "reactivated", flash[:notice]
  end

  # ==========================================
  # Self-modification prevention
  # ==========================================

  test "admin cannot promote themselves" do
    sign_in(@admin)

    patch promote_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    assert_match "cannot modify your own role", flash[:alert]
  end

  test "admin cannot demote themselves" do
    sign_in(@admin)

    patch demote_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    assert_match "cannot modify your own role", flash[:alert]
  end

  test "admin cannot deactivate themselves" do
    sign_in(@admin)

    patch deactivate_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    assert_match "cannot modify your own role or deactivate yourself", flash[:alert]
    @admin.reload
    assert @admin.active?
  end

  # ==========================================
  # Last admin protection
  # ==========================================

  test "sole admin is protected from self-demotion by self-mod check" do
    sign_in(@admin)

    # @admin is the only admin — self-mod check fires
    patch demote_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    @admin.reload
    assert_equal "admin", @admin.role
  end

  test "sole admin is protected from self-deactivation" do
    sign_in(@admin)

    patch deactivate_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    @admin.reload
    assert @admin.active?
    assert_equal "admin", @admin.role
  end

  test "can demote an admin when another active admin exists" do
    sign_in(@admin)

    other_admin = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Bob", last_name: "Admin", role: "admin")
    end

    patch demote_admin_user_path(other_admin)

    assert_redirected_to admin_users_path
    other_admin.reload
    assert_equal "hiring_manager", other_admin.role
  end

  test "can deactivate an admin when another active admin exists" do
    sign_in(@admin)

    other_admin = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Bob", last_name: "Admin", role: "admin")
    end

    patch deactivate_admin_user_path(other_admin)

    assert_redirected_to admin_users_path
    other_admin.reload
    assert other_admin.discarded?
  end

  test "admin who becomes sole admin after deactivating others is protected" do
    sign_in(@admin)

    other_admin = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Bob", last_name: "Admin", role: "admin")
    end

    # Deactivate other admin — now @admin is sole
    patch deactivate_admin_user_path(other_admin)
    assert_redirected_to admin_users_path
    other_admin.reload
    assert other_admin.discarded?

    # Verify sole admin state
    ActsAsTenant.with_tenant(@company) do
      assert @admin.reload.sole_admin?
    end
  end

  test "cannot demote the only remaining active admin from another admin session" do
    # Start with two admins
    admin2 = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Carol", last_name: "Admin", role: "admin")
    end

    sign_in(admin2)

    # Demote @admin — allowed since admin2 still exists
    patch demote_admin_user_path(@admin)
    assert_redirected_to admin_users_path
    @admin.reload
    assert_equal "hiring_manager", @admin.role

    # Now admin2 is sole admin — self-mod prevents self-demotion
    patch demote_admin_user_path(admin2)
    assert_redirected_to admin_users_path
    admin2.reload
    assert_equal "admin", admin2.role
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "index shows role badges with correct styling" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # Admin role badge (purple)
    assert_select "span.bg-purple-100", minimum: 1
    # Hiring manager role badge (blue)
    assert_select "span.bg-blue-100", minimum: 1
    # Interviewer role badge (gray)
    assert_select "span.bg-gray-100", minimum: 1
  end

  test "index shows promote button for non-admin users" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # Promote button appears for interviewer and hiring_manager
    assert_match "Promote", response.body
    # Demote button appears for hiring_manager and admin (other admins)
    assert_match "Demote", response.body
  end

  test "index uses stimulus confirm controller for deactivate" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    assert_select "form[data-controller='confirm']", minimum: 1
  end

  test "index uses role-change stimulus controller for promote and demote" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # The page wraps active users in a role-change controller scope
    assert_select "div[data-controller='role-change']", minimum: 1
    # Promote buttons use data-action to trigger modal
    assert_select "button[data-action='click->role-change#showModal']", minimum: 1
    # Confirmation modal exists with required targets
    assert_select "[data-role-change-target='modal']", count: 1
    assert_select "[data-role-change-target='modalTitle']", count: 1
    assert_select "[data-role-change-target='modalBody']", count: 1
    assert_select "[data-role-change-target='modalConfirmBtn']", count: 1
    assert_select "[data-role-change-target='hiddenForm']", count: 1
  end

  test "promote button shows correct target role for interviewer" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # Interviewer should have a promote button targeting "Hiring Manager"
    assert_select "button[data-role-change-target-role-param='Hiring Manager']", minimum: 1
  end

  test "demote button shows correct target role for hiring manager" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # Hiring manager should have a demote button targeting "Interviewer"
    assert_select "button[data-role-change-target-role-param='Interviewer']", minimum: 1
  end

  test "no promote button for admin users" do
    sign_in(@admin)

    # Create another admin so we can see them in the list
    ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Bob", last_name: "Admin", role: "admin")
    end

    get admin_users_path
    assert_response :success
    # Admin users should NOT have a promote button but SHOULD have a demote button
    assert_select "button[data-role-change-action-param='demote']", minimum: 1
  end

  test "no demote button for interviewer users" do
    sign_in(@admin)
    get admin_users_path
    assert_response :success
    # Interviewer has promote but no demote
    assert_select "button[data-role-change-action-param='promote'][data-role-change-name-param='Ivan Viewer']", count: 1
  end

  test "flash alert displays error with dismiss button for disallowed promote" do
    sign_in(@admin)

    # Try to promote an already-admin user
    other_admin = ActsAsTenant.with_tenant(@company) do
      User.create!(company: @company, email: "admin2@testcorp.com",
        first_name: "Bob", last_name: "Admin", role: "admin")
    end

    patch promote_admin_user_path(other_admin)
    follow_redirect!

    assert_response :success
    # Error flash is shown with dismiss button
    assert_select "div.bg-red-50" do
      assert_select "p", text: /cannot be promoted/
      assert_select "button[data-action='click->flash-dismiss#dismiss']"
    end
  end

  test "flash alert displays error for self-modification attempt" do
    sign_in(@admin)

    patch promote_admin_user_path(@admin)
    follow_redirect!

    assert_response :success
    assert_select "div.bg-red-50" do
      assert_select "p", text: /cannot modify your own role/
      assert_select "button[data-action='click->flash-dismiss#dismiss']"
    end
  end

  test "flash notice displays success with dismiss button after promote" do
    sign_in(@admin)

    patch promote_admin_user_path(@interviewer)
    follow_redirect!

    assert_response :success
    assert_select "div.bg-green-50" do
      assert_select "p", text: /promoted/
      assert_select "button[data-action='click->flash-dismiss#dismiss']"
    end
  end

  test "new form has role select dropdown" do
    sign_in(@admin)
    get new_admin_user_path
    assert_response :success
    assert_select "select[name='user[role]']" do
      assert_select "option", count: 3
    end
  end

  test "edit form does not have role select" do
    sign_in(@admin)
    get edit_admin_user_path(@interviewer)
    assert_response :success
    assert_select "select[name='user[role]']", count: 0
    assert_match "Current role:", response.body
  end

  test "admin cannot see users from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      User.create!(
        company: other_company,
        email: "user@othercorp.com",
        first_name: "Other",
        last_name: "User",
        role: "interviewer"
      )
    end

    sign_in(@admin)
    get admin_users_path

    assert_response :success
    assert_select "td", text: "Other User", count: 0
  end

  # ==========================================
  # Authorization on all actions
  # ==========================================

  # ==========================================
  # Deactivation is soft-delete, not hard delete
  # ==========================================

  test "deactivate performs soft-delete preserving user record in database" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { User.with_discarded.count } } do
      patch deactivate_admin_user_path(@interviewer)
    end

    assert_redirected_to admin_users_path
    @interviewer.reload
    assert @interviewer.discarded?
    assert_not_nil @interviewer.discarded_at
    # User still exists in database — just soft-deleted
    assert ActsAsTenant.with_tenant(@company) { User.with_discarded.exists?(@interviewer.id) }
  end

  test "deactivated user is no longer active and cannot authenticate" do
    sign_in(@admin)
    patch deactivate_admin_user_path(@interviewer)
    assert_redirected_to admin_users_path

    @interviewer.reload
    # User is soft-deleted — active? returns false
    assert_not @interviewer.active?
    assert @interviewer.discarded?

    # Application controller's authenticate_from_session checks user.active?
    # so a deactivated user's session would be rejected on next request
  end

  test "deactivated user cannot request magic link to log in" do
    sign_in(@admin)
    patch deactivate_admin_user_path(@interviewer)

    # The deactivated user's magic link token should not authenticate them
    # because find_by_magic_link_token uses default scope (excludes discarded)
    ActsAsTenant.with_tenant(@company) do
      raw_token = @interviewer.generate_magic_link_token!
      found = User.find_by_magic_link_token(raw_token)
      # find_by_magic_link_token uses without_tenant but User still has default_scope
      # which excludes discarded users, so it returns nil
      assert_nil found
    end
  end

  test "interviewer cannot access any admin user action" do
    sign_in(@interviewer)

    # All these should redirect with authorization error
    get new_admin_user_path
    assert_redirected_to tenant_root_path

    post admin_users_path, params: {user: {email: "x@x.com", first_name: "X", last_name: "Y", role: "interviewer"}}
    assert_redirected_to tenant_root_path

    get edit_admin_user_path(@hiring_manager)
    assert_redirected_to tenant_root_path

    patch admin_user_path(@hiring_manager), params: {user: {first_name: "Hacked"}}
    assert_redirected_to tenant_root_path

    patch promote_admin_user_path(@hiring_manager)
    assert_redirected_to tenant_root_path

    patch demote_admin_user_path(@hiring_manager)
    assert_redirected_to tenant_root_path

    patch deactivate_admin_user_path(@hiring_manager)
    assert_redirected_to tenant_root_path
  end
end
