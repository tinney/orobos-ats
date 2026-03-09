require "test_helper"

class Admin::RolesControllerTest < ActionDispatch::IntegrationTest
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
      @role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft",
        location: "San Francisco, CA",
        remote: false,
        salary_min: 100_000,
        salary_max: 150_000,
        salary_currency: "USD"
      )
    end

    host! "testcorp.example.com"
  end

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  # ==========================================
  # Authorization
  # ==========================================

  test "unauthenticated user is redirected" do
    get admin_roles_path
    assert_response :redirect
  end

  test "interviewer cannot access roles" do
    sign_in(@interviewer)
    get admin_roles_path
    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "hiring manager can access roles index" do
    sign_in(@hiring_manager)
    get admin_roles_path
    assert_response :success
  end

  test "admin can access roles index" do
    sign_in(@admin)
    get admin_roles_path
    assert_response :success
  end

  # ==========================================
  # Index
  # ==========================================

  test "index lists roles with status badges" do
    sign_in(@admin)
    get admin_roles_path
    assert_response :success
    assert_match "Software Engineer", response.body
    assert_select "span", text: "Draft", minimum: 1
  end

  test "index shows empty state when no roles exist" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { Role.destroy_all }

    get admin_roles_path
    assert_response :success
    assert_match "No roles yet", response.body
  end

  # ==========================================
  # New / Create
  # ==========================================

  test "new renders form with Trix editor" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "form"
    assert_select "trix-editor"
  end

  test "new form has role-form stimulus controller" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "form[data-controller='role-form']"
  end

  test "create adds a new role" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { Role.count } }, 1 do
      post admin_roles_path, params: {
        role: {
          title: "Product Manager",
          location: "Remote",
          remote: true,
          salary_min: 120_000,
          salary_max: 180_000,
          salary_currency: "USD",
          status: "draft"
        }
      }
    end

    assert_redirected_to admin_roles_path
    assert_match "Product Manager", flash[:notice]

    new_role = ActsAsTenant.with_tenant(@company) { Role.find_by(title: "Product Manager") }
    assert_equal @company.id, new_role.company_id
    assert new_role.remote?
  end

  test "create with invalid data re-renders form" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {title: "", status: "draft"}
    }

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "hiring manager can create a role" do
    sign_in(@hiring_manager)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { Role.count } }, 1 do
      post admin_roles_path, params: {
        role: {
          title: "Designer",
          status: "draft"
        }
      }
    end

    assert_redirected_to admin_roles_path
  end

  # ==========================================
  # Edit / Update
  # ==========================================

  test "edit renders form for existing role" do
    sign_in(@admin)
    get edit_admin_role_path(@role)
    assert_response :success
    assert_select "form"
    assert_select "trix-editor"
  end

  test "update changes role attributes" do
    sign_in(@admin)

    patch admin_role_path(@role), params: {
      role: {title: "Senior Software Engineer", location: "New York, NY"}
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "Senior Software Engineer", @role.title
    assert_equal "New York, NY", @role.location
  end

  test "update with invalid data re-renders form" do
    sign_in(@admin)

    patch admin_role_path(@role), params: {
      role: {title: ""}
    }

    assert_response :unprocessable_entity
  end

  test "update can change status" do
    sign_in(@admin)

    patch admin_role_path(@role), params: {
      role: {status: "published"}
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "published", @role.status
  end

  test "hiring manager can update a role" do
    sign_in(@hiring_manager)

    patch admin_role_path(@role), params: {
      role: {title: "Updated Title"}
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "Updated Title", @role.title
  end

  # ==========================================
  # Form fields
  # ==========================================

  test "form has all required fields" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "input[name='role[title]']"
    assert_select "input[name='role[location]']"
    assert_select "input[name='role[remote]']"
    assert_select "input[name='role[salary_min]']"
    assert_select "input[name='role[salary_max]']"
    assert_select "select[name='role[salary_currency]']"
    assert_select "select[name='role[status]']"
    assert_select "select[name='role[hiring_manager_id]']"
    assert_select "trix-editor"
  end

  test "form has hiring manager select with available managers" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "select[name='role[hiring_manager_id]']" do
      # Should have blank option + admin + hiring_manager (not interviewer)
      assert_select "option", minimum: 3
      assert_select "option[value='#{@admin.id}']"
      assert_select "option[value='#{@hiring_manager.id}']"
    end
    # Interviewer should not be in the hiring manager dropdown
    assert_select "option[value='#{@interviewer.id}']", count: 0
  end

  test "form has card sections for basic info, compensation, and description" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_match "Basic Information", response.body
    assert_match "Compensation", response.body
    assert_match "Role Description", response.body
  end

  test "form has stimulus controller with salary validation targets" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "[data-role-form-target='salaryMin']"
    assert_select "[data-role-form-target='salaryMax']"
    assert_select "[data-role-form-target='salaryError']"
  end

  test "form has trix editor wrapper with word count target" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select ".trix-editor-wrapper"
    assert_select "[data-role-form-target='wordCount']"
  end

  test "create with hiring manager assigns the manager" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {
        title: "Engineering Lead",
        status: "draft",
        hiring_manager_id: @hiring_manager.id
      }
    }

    assert_redirected_to admin_roles_path
    new_role = ActsAsTenant.with_tenant(@company) { Role.find_by(title: "Engineering Lead") }
    assert_equal @hiring_manager.id, new_role.hiring_manager_id
  end

  test "update can change hiring manager" do
    sign_in(@admin)

    patch admin_role_path(@role), params: {
      role: {hiring_manager_id: @hiring_manager.id}
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal @hiring_manager.id, @role.hiring_manager_id
  end

  test "edit form pre-selects current hiring manager" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(hiring_manager: @hiring_manager) }
    get edit_admin_role_path(@role)
    assert_response :success
    assert_select "select[name='role[hiring_manager_id]'] option[selected][value='#{@hiring_manager.id}']"
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "admin cannot see roles from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      Role.create!(
        company: other_company,
        title: "Secret Role",
        status: "published"
      )
    end

    sign_in(@admin)
    get admin_roles_path
    assert_response :success
    assert_no_match "Secret Role", response.body
  end

  test "cannot edit a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    get edit_admin_role_path(other_role)
    assert_response :not_found
  end

  test "cannot update a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    patch admin_role_path(other_role), params: {role: {title: "Hacked"}}
    assert_response :not_found
  end

  # ==========================================
  # Interviewer blocked on all actions
  # ==========================================

  test "interviewer cannot access any roles action" do
    sign_in(@interviewer)

    get admin_roles_path
    assert_redirected_to tenant_root_path

    get new_admin_role_path
    assert_redirected_to tenant_root_path

    post admin_roles_path, params: {role: {title: "Hack", status: "draft"}}
    assert_redirected_to tenant_root_path

    get edit_admin_role_path(@role)
    assert_redirected_to tenant_root_path

    patch admin_role_path(@role), params: {role: {title: "Hacked"}}
    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Navigation
  # ==========================================

  test "admin layout includes Roles nav link" do
    sign_in(@hiring_manager)
    get admin_roles_path
    assert_response :success
    assert_select "a[href='#{admin_roles_path}']", text: "Roles"
  end

  # ==========================================
  # Salary validation
  # ==========================================

  test "create with salary_max less than salary_min fails" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {title: "Bad Salary", status: "draft", salary_min: 100_000, salary_max: 50_000}
    }

    assert_response :unprocessable_entity
  end

  test "create with invalid status fails" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {title: "Some Role", status: "bogus"}
    }

    assert_response :unprocessable_entity
  end

  # ==========================================
  # Show
  # ==========================================

  test "show displays role details" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Software Engineer", response.body
    assert_select "span", text: "Draft", minimum: 1
  end

  test "show displays salary range" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "100,000", response.body
  end

  test "hiring manager can view show page" do
    sign_in(@hiring_manager)
    get admin_role_path(@role)
    assert_response :success
  end

  test "interviewer cannot access show page" do
    sign_in(@interviewer)
    get admin_role_path(@role)
    assert_redirected_to tenant_root_path
  end

  test "cannot show a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    get admin_role_path(other_role)
    assert_response :not_found
  end

  # ==========================================
  # Transition
  # ==========================================

  test "transition publishes a draft role with phase owner" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    patch transition_admin_role_path(@role), params: {status: "published"}
    assert_redirected_to admin_role_path(@role)
    assert_match "Published", flash[:notice]
    @role.reload
    assert_equal "published", @role.status
  end

  test "transition rejects publishing without phase owner" do
    sign_in(@admin)
    patch transition_admin_role_path(@role), params: {status: "published"}
    assert_redirected_to admin_role_path(@role)
    assert_match "at least one interview phase must have a phase owner", flash[:alert]
    @role.reload
    assert_equal "draft", @role.status
  end

  test "transition makes a published role internal only" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    patch transition_admin_role_path(@role), params: {status: "internal_only"}
    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "internal_only", @role.status
  end

  test "transition closes a published role" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    patch transition_admin_role_path(@role), params: {status: "closed"}
    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "closed", @role.status
  end

  test "transition rejects invalid transition" do
    sign_in(@admin)
    # draft cannot go directly to closed
    patch transition_admin_role_path(@role), params: {status: "closed"}
    assert_redirected_to admin_role_path(@role)
    assert_match "Cannot transition", flash[:alert]
    @role.reload
    assert_equal "draft", @role.status
  end

  test "transition rejects transition from terminal state" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "closed") }
    patch transition_admin_role_path(@role), params: {status: "published"}
    assert_redirected_to admin_role_path(@role)
    assert_match "Cannot transition", flash[:alert]
    @role.reload
    assert_equal "closed", @role.status
  end

  test "hiring manager can trigger transitions" do
    sign_in(@hiring_manager)
    assign_phase_owner_to(@role)
    patch transition_admin_role_path(@role), params: {status: "published"}
    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal "published", @role.status
  end

  test "interviewer cannot trigger transitions" do
    sign_in(@interviewer)
    patch transition_admin_role_path(@role), params: {status: "published"}
    assert_redirected_to tenant_root_path
    @role.reload
    assert_equal "draft", @role.status
  end

  test "cannot transition a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    patch transition_admin_role_path(other_role), params: {status: "published"}
    assert_response :not_found
  end

  # ==========================================
  # UI transition buttons
  # ==========================================

  test "show page shows publish button for publishable draft role" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Publish", response.body
    assert_select "form[action*='transition']", minimum: 1
  end

  test "show page hides publish transition button when no phase owner assigned but shows other transitions" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    # Publish transition button is hidden (no phase owner), but internal_only is still available for draft
    assert_select "form[action*='transition'] input[value='published']", count: 0
    assert_select "form[action*='transition']", minimum: 1
  end

  test "show page shows publishing blocked warning when not publishable" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Publishing blocked", response.body
  end

  test "show page shows internal and close buttons for published role" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get admin_role_path(@role)
    assert_response :success
    assert_match "Make Internal", response.body
    assert_match "Close", response.body
  end

  test "show page shows revert to draft button for closed role" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "closed") }
    get admin_role_path(@role)
    assert_response :success
    assert_match "Revert to Draft", response.body
    assert_select "form[action*='transition']", count: 1
  end

  test "index page shows transition buttons when publishable" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_roles_path
    assert_response :success
    # Draft role with phase owner should have Publish button
    assert_match "Publish", response.body
    assert_select "form[action*='transition']", minimum: 1
  end

  # ==========================================
  # Stimulus transition dropdown and confirmation UI
  # ==========================================

  test "transition buttons render inside a role-transition stimulus controller" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_role_path(@role)
    assert_response :success
    assert_select "[data-controller='role-transition']", minimum: 1
  end

  test "transition dropdown has a toggle trigger button" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_role_path(@role)
    assert_response :success
    assert_select "[data-action='click->role-transition#toggle']", minimum: 1
    assert_match "Status Actions", response.body
  end

  test "transition dropdown has a hidden menu target" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_role_path(@role)
    assert_response :success
    assert_select "[data-role-transition-target='menu']", minimum: 1
  end

  test "close transition has destructive confirmation action" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get admin_role_path(@role)
    assert_response :success
    assert_select "form[data-action='submit->role-transition#confirmDestructive']", minimum: 1
    assert_match "Close Role", response.body
  end

  test "non-destructive transitions use confirmTransition action" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get admin_role_path(@role)
    assert_response :success
    assert_select "form[data-action='submit->role-transition#confirmTransition']", minimum: 1
  end

  test "close transition confirm message warns about removing from public listings" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get admin_role_path(@role)
    assert_response :success
    assert_match "remove it from public listings", response.body
  end

  test "delete button uses confirm stimulus controller" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "form[data-controller='confirm'][data-action='submit->confirm#submit']", minimum: 1
    assert_select "form[data-confirm-message-value*='permanently remove']", minimum: 1
  end

  test "index page renders transition dropdown with stimulus controller" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get admin_roles_path
    assert_response :success
    assert_select "[data-controller='role-transition']", minimum: 1
    assert_select "[data-action='click->role-transition#toggle']", minimum: 1
  end

  test "edit page renders transition dropdown" do
    sign_in(@admin)
    assign_phase_owner_to(@role)
    get edit_admin_role_path(@role)
    assert_response :success
    assert_select "[data-controller='role-transition']", minimum: 1
  end

  # ==========================================
  # Phase owner assignment via interview phases
  # ==========================================

  test "show page displays phase owner dropdown" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "select[name='interview_phase[phase_owner_id]']", minimum: 1
  end

  test "phase owner can be assigned through interview phase update" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) do
      phase = @role.interview_phases.active.first
      patch admin_role_interview_phase_path(@role, phase), params: {
        interview_phase: {phase_owner_id: @admin.id}
      }
      assert_redirected_to admin_role_path(@role)
      phase.reload
      assert_equal @admin.id, phase.phase_owner_id
    end
  end

  test "phase owner can be cleared" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) do
      phase = @role.interview_phases.active.first
      phase.update!(phase_owner: @admin)
      patch admin_role_interview_phase_path(@role, phase), params: {
        interview_phase: {phase_owner_id: ""}
      }
      assert_redirected_to admin_role_path(@role)
      phase.reload
      assert_nil phase.phase_owner_id
    end
  end

  # ==========================================
  # Preview token management
  # ==========================================

  test "admin can generate preview token" do
    sign_in(@admin)
    post generate_preview_token_admin_role_path(@role)
    assert_redirected_to admin_role_path(@role)
    assert_match "Preview link generated", flash[:notice]
    @role.reload
    assert @role.preview_token.present?
  end

  test "hiring manager can generate preview token" do
    sign_in(@hiring_manager)
    post generate_preview_token_admin_role_path(@role)
    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert @role.preview_token.present?
  end

  test "interviewer cannot generate preview token" do
    sign_in(@interviewer)
    post generate_preview_token_admin_role_path(@role)
    assert_redirected_to tenant_root_path
    @role.reload
    assert_nil @role.preview_token
  end

  test "admin can revoke preview token" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    delete revoke_preview_token_admin_role_path(@role)
    assert_redirected_to admin_role_path(@role)
    assert_match "Preview link revoked", flash[:notice]
    @role.reload
    assert_nil @role.preview_token
  end

  test "hiring manager can revoke preview token" do
    sign_in(@hiring_manager)
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    delete revoke_preview_token_admin_role_path(@role)
    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_nil @role.preview_token
  end

  test "interviewer cannot revoke preview token" do
    sign_in(@interviewer)
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    delete revoke_preview_token_admin_role_path(@role)
    assert_redirected_to tenant_root_path
    @role.reload
    assert @role.preview_token.present?
  end

  test "show page displays preview link section" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Preview Link", response.body
    assert_match "Generate Preview Link", response.body
  end

  test "show page displays preview URL when token exists" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get admin_role_path(@role)
    assert_response :success
    assert_match @role.reload.preview_token, response.body
    assert_match "Revoke", response.body
  end

  # ==========================================
  # Shareable URL
  # ==========================================

  test "show page displays shareable URL section" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Shareable URL", response.body
    assert_match @role.slug, response.body
  end

  test "show page displays copyable shareable URL with correct slug" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "input[readonly][value*='#{@role.slug}']"
    assert_select "[data-controller='clipboard']"
    assert_select "[data-action='click->clipboard#copy']"
  end

  test "shareable URL contains tenant subdomain" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "testcorp", response.body
    assert_select "input[readonly][value*='testcorp']"
  end

  test "shareable URL indicates status context for published role" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get admin_role_path(@role)
    assert_response :success
    assert_match "public link is live", response.body
  end

  test "shareable URL indicates status context for draft role" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "will become active when the role is published", response.body
  end

  test "hiring manager can see shareable URL" do
    sign_in(@hiring_manager)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Shareable URL", response.body
    assert_match @role.slug, response.body
  end

  test "cannot generate preview token for another tenant role" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    post generate_preview_token_admin_role_path(other_role)
    assert_response :not_found
  end

  # ==========================================
  # Destroy
  # ==========================================

  test "admin can destroy a role" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { Role.count } }, -1 do
      delete admin_role_path(@role)
    end

    assert_redirected_to admin_roles_path
    assert_match "Software Engineer", flash[:notice]
    assert_match "deleted", flash[:notice]
  end

  test "hiring manager cannot destroy a role" do
    sign_in(@hiring_manager)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { Role.count } } do
      delete admin_role_path(@role)
    end

    assert_redirected_to tenant_root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "interviewer cannot destroy a role" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { Role.count } } do
      delete admin_role_path(@role)
    end

    assert_redirected_to tenant_root_path
  end

  test "cannot destroy a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    delete admin_role_path(other_role)
    assert_response :not_found
  end

  test "destroy removes associated interview phases" do
    sign_in(@admin)
    phase_count = ActsAsTenant.with_tenant(@company) { @role.interview_phases.count }
    assert phase_count > 0, "Role should have default phases"

    assert_difference -> { ActsAsTenant.with_tenant(@company) { InterviewPhase.count } }, -phase_count do
      delete admin_role_path(@role)
    end
  end

  # ==========================================
  # Hiring Manager Assignment
  # ==========================================

  test "create role with hiring manager assignment" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {
        title: "QA Engineer",
        status: "draft",
        hiring_manager_id: @hiring_manager.id
      }
    }

    assert_redirected_to admin_roles_path
    new_role = ActsAsTenant.with_tenant(@company) { Role.find_by(title: "QA Engineer") }
    assert_equal @hiring_manager.id, new_role.hiring_manager_id
  end

  test "update role hiring manager" do
    sign_in(@admin)

    patch admin_role_path(@role), params: {
      role: { hiring_manager_id: @hiring_manager.id }
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal @hiring_manager.id, @role.hiring_manager_id
  end

  test "clear role hiring manager" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(hiring_manager: @hiring_manager) }

    patch admin_role_path(@role), params: {
      role: { hiring_manager_id: "" }
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_nil @role.hiring_manager_id
  end

  test "show page displays hiring manager" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @role.update!(hiring_manager: @hiring_manager) }

    get admin_role_path(@role)
    assert_response :success
    assert_match "Harry Manager", response.body
    assert_match "Hiring Manager", response.body
  end

  test "form has hiring manager select field" do
    sign_in(@admin)
    get new_admin_role_path
    assert_response :success
    assert_select "select[name='role[hiring_manager_id]']"
  end

  test "edit form has hiring manager select field" do
    sign_in(@admin)
    get edit_admin_role_path(@role)
    assert_response :success
    assert_select "select[name='role[hiring_manager_id]']"
  end

  test "hiring manager can assign hiring manager to role" do
    sign_in(@hiring_manager)

    patch admin_role_path(@role), params: {
      role: { hiring_manager_id: @hiring_manager.id }
    }

    assert_redirected_to admin_role_path(@role)
    @role.reload
    assert_equal @hiring_manager.id, @role.hiring_manager_id
  end

  # ==========================================
  # Strong parameter filtering
  # ==========================================

  test "unpermitted parameters are ignored" do
    sign_in(@admin)

    post admin_roles_path, params: {
      role: {
        title: "Test Role",
        status: "draft",
        company_id: "00000000-0000-0000-0000-000000000000",
        slug: "hacked-slug"
      }
    }

    assert_redirected_to admin_roles_path
    new_role = ActsAsTenant.with_tenant(@company) { Role.find_by(title: "Test Role") }
    assert_equal @company.id, new_role.company_id
    assert_not_equal "hacked-slug", new_role.slug
  end

  private

  def assign_phase_owner_to(role)
    ActsAsTenant.with_tenant(@company) do
      phase = role.interview_phases.active.first
      phase.update!(phase_owner: @admin)
    end
  end
end
