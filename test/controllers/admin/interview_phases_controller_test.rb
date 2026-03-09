# frozen_string_literal: true

require "test_helper"

class Admin::InterviewPhasesControllerTest < ActionDispatch::IntegrationTest
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
        status: "draft"
      )
      # Role.create! seeds default phases (4 phases)
      @phases = @role.interview_phases.ordered.to_a
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

  test "unauthenticated user cannot create interview phase" do
    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "New Phase"}
    }
    assert_response :redirect
  end

  test "interviewer cannot create interview phase" do
    sign_in(@interviewer)
    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "New Phase"}
    }
    assert_redirected_to tenant_root_path
  end

  test "hiring manager can create interview phase" do
    sign_in(@hiring_manager)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } }, 1 do
      post admin_role_interview_phases_path(@role), params: {
        interview_phase: {name: "Culture Fit"}
      }
    end

    assert_redirected_to admin_role_path(@role)
    assert_match "Culture Fit", flash[:notice]
  end

  test "admin can create interview phase" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } }, 1 do
      post admin_role_interview_phases_path(@role), params: {
        interview_phase: {name: "Culture Fit"}
      }
    end

    assert_redirected_to admin_role_path(@role)
  end

  # ==========================================
  # Create
  # ==========================================

  test "create assigns correct position to new phase" do
    sign_in(@admin)

    post admin_role_interview_phases_path(@role), params: {
      interview_phase: {name: "Culture Fit"}
    }

    new_phase = ActsAsTenant.with_tenant(@company) { @role.interview_phases.find_by(name: "Culture Fit") }
    assert_equal 4, new_phase.position # 0-indexed, after 4 default phases
  end

  test "create with blank name redirects with error" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } } do
      post admin_role_interview_phases_path(@role), params: {
        interview_phase: {name: ""}
      }
    end

    assert_redirected_to admin_role_path(@role)
    assert flash[:alert].present?
  end

  test "create with duplicate name redirects with error" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } } do
      post admin_role_interview_phases_path(@role), params: {
        interview_phase: {name: @phases.first.name}
      }
    end

    assert_redirected_to admin_role_path(@role)
    assert flash[:alert].present?
  end

  # ==========================================
  # Update (rename)
  # ==========================================

  test "update renames an interview phase" do
    sign_in(@admin)

    phase = @phases.first
    patch admin_role_interview_phase_path(@role, phase), params: {
      interview_phase: {name: "Initial Screening"}
    }

    assert_redirected_to admin_role_path(@role)
    assert_match "Initial Screening", flash[:notice]

    ActsAsTenant.with_tenant(@company) { phase.reload }
    assert_equal "Initial Screening", phase.name
  end

  test "update with invalid name redirects with error" do
    sign_in(@admin)

    phase = @phases.first
    patch admin_role_interview_phase_path(@role, phase), params: {
      interview_phase: {name: ""}
    }

    assert_redirected_to admin_role_path(@role)
    assert flash[:alert].present?
  end

  test "interviewer cannot update interview phase" do
    sign_in(@interviewer)
    phase = @phases.first

    patch admin_role_interview_phase_path(@role, phase), params: {
      interview_phase: {name: "Hacked"}
    }

    assert_redirected_to tenant_root_path
    ActsAsTenant.with_tenant(@company) { phase.reload }
    assert_not_equal "Hacked", phase.name
  end

  # ==========================================
  # Destroy
  # ==========================================

  test "destroy removes an interview phase" do
    sign_in(@admin)

    phase = @phases.last
    assert_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } }, -1 do
      delete admin_role_interview_phase_path(@role, phase)
    end

    assert_redirected_to admin_role_path(@role)
    assert_match "removed", flash[:notice]
  end

  test "destroy recompacts positions" do
    sign_in(@admin)

    # Delete the second phase (position 1)
    delete admin_role_interview_phase_path(@role, @phases[1])

    remaining = ActsAsTenant.with_tenant(@company) { @role.interview_phases.ordered.to_a }
    assert_equal 3, remaining.length
    assert_equal [0, 1, 2], remaining.map(&:position)
  end

  test "interviewer cannot destroy interview phase" do
    sign_in(@interviewer)
    phase = @phases.first

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { @role.interview_phases.count } } do
      delete admin_role_interview_phase_path(@role, phase)
    end

    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Move (reorder)
  # ==========================================

  test "move changes phase position" do
    sign_in(@admin)

    # Move first phase to position 2
    phase = @phases.first
    patch move_admin_role_interview_phase_path(@role, phase), params: {position: 2}

    assert_redirected_to admin_role_path(@role)
    assert_match "moved", flash[:notice]

    reordered = ActsAsTenant.with_tenant(@company) { @role.interview_phases.ordered.pluck(:name) }
    assert_equal "Technical Interview", reordered[0]
    assert_equal "Onsite Interview", reordered[1]
    assert_equal "Phone Screen", reordered[2]
    assert_equal "Final Interview", reordered[3]
  end

  test "move to same position is a no-op" do
    sign_in(@admin)

    phase = @phases.first
    patch move_admin_role_interview_phase_path(@role, phase), params: {position: 0}

    assert_redirected_to admin_role_path(@role)

    reordered = ActsAsTenant.with_tenant(@company) { @role.interview_phases.ordered.pluck(:name) }
    assert_equal %w[Phone\ Screen Technical\ Interview Onsite\ Interview Final\ Interview], reordered
  end

  test "interviewer cannot move interview phase" do
    sign_in(@interviewer)

    phase = @phases.first
    patch move_admin_role_interview_phase_path(@role, phase), params: {position: 2}

    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "cannot manage phases for a role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)

    # Attempt to create phase on another tenant's role
    post admin_role_interview_phases_path(other_role), params: {
      interview_phase: {name: "Sneaky Phase"}
    }
    assert_response :not_found
  end

  test "cannot modify a phase from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end
    other_phase = ActsAsTenant.with_tenant(other_company) do
      other_role.interview_phases.first
    end

    sign_in(@admin)

    patch admin_role_interview_phase_path(other_role, other_phase), params: {
      interview_phase: {name: "Hacked"}
    }
    assert_response :not_found
  end

  # ==========================================
  # Phase owner assignment via dropdown
  # ==========================================

  test "update assigns phase owner via dropdown" do
    sign_in(@admin)

    phase = @phases.first
    patch admin_role_interview_phase_path(@role, phase), params: {
      interview_phase: { phase_owner_id: @hiring_manager.id }
    }

    assert_redirected_to admin_role_path(@role)
    ActsAsTenant.with_tenant(@company) { phase.reload }
    assert_equal @hiring_manager.id, phase.phase_owner_id
  end

  test "update clears phase owner when set to blank" do
    sign_in(@admin)

    phase = @phases.first
    ActsAsTenant.with_tenant(@company) { phase.update!(phase_owner: @hiring_manager) }

    patch admin_role_interview_phase_path(@role, phase), params: {
      interview_phase: { phase_owner_id: "" }
    }

    assert_redirected_to admin_role_path(@role)
    ActsAsTenant.with_tenant(@company) { phase.reload }
    assert_nil phase.phase_owner_id
  end

  test "role show page displays phase owner dropdown for each phase" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    # Each phase should have a select for phase_owner_id
    assert_select "select[name='interview_phase[phase_owner_id]']", count: @phases.length
  end

  test "phase owner dropdown includes hiring managers and admins" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    # The dropdown should include the admin and hiring manager but not the interviewer
    assert_match @admin.full_name, response.body
    assert_match @hiring_manager.full_name, response.body
  end

  test "phase owner dropdown shows current owner as selected" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @phases.first.update!(phase_owner: @hiring_manager) }

    get admin_role_path(@role)
    assert_response :success
    assert_select "select[name='interview_phase[phase_owner_id]'] option[selected][value='#{@hiring_manager.id}']"
  end

  # ==========================================
  # Role show page displays phases
  # ==========================================

  test "role show page displays interview phases in order" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_match "Interview Phases", response.body
    assert_match "Phone Screen", response.body
    assert_match "Technical Interview", response.body
    assert_match "Onsite Interview", response.body
    assert_match "Final Interview", response.body
  end

  test "role show page displays add phase form" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "input[placeholder='New phase name']"
    assert_select "input[type='submit'][value='Add Phase']"
  end

  test "role show page displays move buttons" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    # First phase should not have move-up, last should not have move-down
    assert_select "form[action*='move']"
  end

  test "role show page has phase-reorder stimulus controller" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "[data-controller='phase-reorder']"
  end

  test "role show page has inline-edit stimulus controller for phases" do
    sign_in(@admin)
    get admin_role_path(@role)
    assert_response :success
    assert_select "[data-controller='inline-edit']"
  end
end
