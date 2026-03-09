# frozen_string_literal: true

require "test_helper"

class Admin::ScorecardTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company,
        email: "admin@scorecardtest.com",
        first_name: "Alice",
        last_name: "Admin",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        email: "hm@scorecardtest.com",
        first_name: "Harry",
        last_name: "Manager",
        role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company,
        email: "interviewer@scorecardtest.com",
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
      @template = ScorecardsTemplate.create!(
        company: @company,
        interview_phase_id: @phase.id,
        name: "Technical Assessment",
        description: "Evaluate technical skills"
      )
      @category = ScorecardTemplateCategory.create!(
        scorecards_template: @template,
        name: "Problem Solving",
        sort_order: 0,
        rating_scale: 5
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

  test "unauthenticated user cannot access scorecard templates" do
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_response :redirect
  end

  test "interviewer cannot access scorecard templates" do
    sign_in(@interviewer)
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_redirected_to tenant_root_path
  end

  test "hiring manager can access scorecard templates" do
    sign_in(@hiring_manager)
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_response :success
  end

  test "admin can access scorecard templates" do
    sign_in(@admin)
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_response :success
  end

  # ==========================================
  # Index
  # ==========================================

  test "index displays templates for the phase" do
    sign_in(@admin)
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)

    assert_response :success
    assert_match "Technical Assessment", response.body
    assert_match "Scorecard Templates", response.body
  end

  test "index displays empty state when no templates exist" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @template.destroy! }
    get admin_role_interview_phase_scorecard_templates_path(@role, @phase)

    assert_response :success
    assert_match "No scorecard templates", response.body
  end

  # ==========================================
  # New
  # ==========================================

  test "new renders form" do
    sign_in(@admin)
    get new_admin_role_interview_phase_scorecard_template_path(@role, @phase)

    assert_response :success
    assert_match "New Scorecard Template", response.body
    assert_select "form"
    assert_select "input[name='scorecards_template[name]']"
  end

  # ==========================================
  # Create
  # ==========================================

  test "create saves a new template with categories" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, 1 do
      post admin_role_interview_phase_scorecard_templates_path(@role, @phase), params: {
        scorecards_template: {
          name: "Culture Fit",
          description: "Evaluate team fit",
          scorecard_template_categories_attributes: {
            "0" => {name: "Communication", sort_order: 0, rating_scale: 5},
            "1" => {name: "Teamwork", sort_order: 1, rating_scale: 5}
          }
        }
      }
    end

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_match "Culture Fit", flash[:notice]

    template = ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.find_by(name: "Culture Fit") }
    assert_equal 2, template.scorecard_template_categories.count
    assert_equal @company.id, template.company_id
  end

  test "create with blank name renders errors" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_role_interview_phase_scorecard_templates_path(@role, @phase), params: {
        scorecards_template: {name: "", description: ""}
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with duplicate name renders errors" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_role_interview_phase_scorecard_templates_path(@role, @phase), params: {
        scorecards_template: {name: "Technical Assessment"}
      }
    end

    assert_response :unprocessable_entity
  end

  test "interviewer cannot create template" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_role_interview_phase_scorecard_templates_path(@role, @phase), params: {
        scorecards_template: {name: "Hacked Template"}
      }
    end

    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Show
  # ==========================================

  test "show displays template with categories" do
    sign_in(@admin)
    get admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)

    assert_response :success
    assert_match "Technical Assessment", response.body
    assert_match "Problem Solving", response.body
    assert_match "1–5", response.body
  end

  # ==========================================
  # Edit
  # ==========================================

  test "edit renders form with existing data" do
    sign_in(@admin)
    get edit_admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)

    assert_response :success
    assert_match "Edit Scorecard Template", response.body
    assert_select "input[name='scorecards_template[name]'][value='Technical Assessment']"
  end

  # ==========================================
  # Update
  # ==========================================

  test "update modifies template" do
    sign_in(@admin)

    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {name: "Updated Assessment"}
    }

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_match "Updated Assessment", flash[:notice]

    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal "Updated Assessment", @template.name
  end

  test "update can add new categories" do
    sign_in(@admin)

    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, name: "Problem Solving", sort_order: 0, rating_scale: 5},
          "1" => {name: "Code Quality", sort_order: 1, rating_scale: 5}
        }
      }
    }

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal 2, @template.scorecard_template_categories.count
  end

  test "update can remove categories" do
    sign_in(@admin)

    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, _destroy: "1"}
        }
      }
    }

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal 0, @template.scorecard_template_categories.count
  end

  test "update can reorder categories" do
    sign_in(@admin)

    ActsAsTenant.with_tenant(@company) do
      @category2 = ScorecardTemplateCategory.create!(
        scorecards_template: @template,
        name: "Code Quality",
        sort_order: 1,
        rating_scale: 5
      )
    end

    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, name: "Problem Solving", sort_order: 1, rating_scale: 5},
          "1" => {id: @category2.id, name: "Code Quality", sort_order: 0, rating_scale: 5}
        }
      }
    }

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    ActsAsTenant.with_tenant(@company) do
      categories = @template.scorecard_template_categories.ordered
      assert_equal "Code Quality", categories.first.name
      assert_equal "Problem Solving", categories.last.name
    end
  end

  test "update with invalid data renders errors" do
    sign_in(@admin)

    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {name: ""}
    }

    assert_response :unprocessable_entity
  end

  # ==========================================
  # Destroy
  # ==========================================

  test "destroy deletes template and categories" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, -1 do
      delete admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)
    end

    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)
    assert_match "Technical Assessment", flash[:notice]

    # Categories should be destroyed too (dependent: :destroy)
    assert_equal 0, ScorecardTemplateCategory.where(scorecards_template_id: @template.id).count
  end

  test "interviewer cannot destroy template" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      delete admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)
    end

    assert_redirected_to tenant_root_path
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "cannot access templates from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Other Role", status: "draft")
    end
    other_phase = ActsAsTenant.with_tenant(other_company) { other_role.interview_phases.first }

    sign_in(@admin)

    get admin_role_interview_phase_scorecard_templates_path(other_role, other_phase)
    assert_response :not_found
  end

  # ==========================================
  # No editing restrictions
  # ==========================================

  test "can edit template freely with no restrictions" do
    sign_in(@admin)

    # First update
    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {name: "Renamed Once"}
    }
    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)

    # Second update
    patch admin_role_interview_phase_scorecard_template_path(@role, @phase, @template), params: {
      scorecards_template: {name: "Renamed Again", description: "New desc"}
    }
    assert_redirected_to admin_role_interview_phase_scorecard_templates_path(@role, @phase)

    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal "Renamed Again", @template.name
    assert_equal "New desc", @template.description
  end

  # ==========================================
  # Stimulus controller present
  # ==========================================

  test "new form has scorecard-template-form stimulus controller" do
    sign_in(@admin)
    get new_admin_role_interview_phase_scorecard_template_path(@role, @phase)

    assert_response :success
    assert_select "[data-controller='scorecard-template-form']"
  end

  test "edit form has scorecard-template-form stimulus controller" do
    sign_in(@admin)
    get edit_admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)

    assert_response :success
    assert_select "[data-controller='scorecard-template-form']"
  end

  # ==========================================
  # Notes field reminder
  # ==========================================

  test "show page mentions automatic notes field" do
    sign_in(@admin)
    get admin_role_interview_phase_scorecard_template_path(@role, @phase, @template)

    assert_response :success
    assert_match "free-form notes field", response.body
  end

  test "form mentions automatic notes field" do
    sign_in(@admin)
    get new_admin_role_interview_phase_scorecard_template_path(@role, @phase)

    assert_response :success
    assert_match "free-form notes field", response.body
  end

  # ==========================================
  # Role show page integration
  # ==========================================

  test "role show page has scorecard templates link for each phase" do
    sign_in(@admin)
    get admin_role_path(@role)

    assert_response :success
    # Each phase should have a link to its scorecard templates
    @role.interview_phases.active.each do |phase|
      assert_match admin_role_interview_phase_scorecard_templates_path(@role, phase), response.body
    end
  end
end
