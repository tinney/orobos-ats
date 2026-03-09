# frozen_string_literal: true

require "test_helper"

class Admin::ScorecardTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.with_tenant(@company) do
      @admin = User.create!(
        company: @company,
        email: "admin@scorecardtpltest.com",
        first_name: "Alice",
        last_name: "Admin",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        email: "hm@scorecardtpltest.com",
        first_name: "Harry",
        last_name: "Manager",
        role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company,
        email: "interviewer@scorecardtpltest.com",
        first_name: "Ivan",
        last_name: "Viewer",
        role: "interviewer"
      )
      @template = ScorecardsTemplate.create!(
        company: @company,
        name: "Technical Assessment",
        description: "Evaluate technical skills"
      )
      @category = ScorecardTemplateCategory.create!(
        scorecards_template: @template,
        name: "Problem Solving",
        sort_order: 0
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
    get admin_scorecard_templates_path
    assert_response :redirect
  end

  test "interviewer cannot access scorecard templates" do
    sign_in(@interviewer)
    get admin_scorecard_templates_path
    assert_redirected_to tenant_root_path
  end

  test "hiring manager can access scorecard templates" do
    sign_in(@hiring_manager)
    get admin_scorecard_templates_path
    assert_response :success
  end

  test "admin can access scorecard templates" do
    sign_in(@admin)
    get admin_scorecard_templates_path
    assert_response :success
  end

  # ==========================================
  # Index
  # ==========================================

  test "index displays templates" do
    sign_in(@admin)
    get admin_scorecard_templates_path

    assert_response :success
    assert_match "Technical Assessment", response.body
    assert_match "Scorecard Templates", response.body
  end

  test "index displays category count" do
    sign_in(@admin)
    get admin_scorecard_templates_path

    assert_response :success
    assert_match "1 categories", response.body
  end

  test "index displays empty state when no templates exist" do
    sign_in(@admin)
    ActsAsTenant.with_tenant(@company) { @template.destroy! }
    get admin_scorecard_templates_path

    assert_response :success
    assert_match "No scorecard templates", response.body
  end

  # ==========================================
  # New
  # ==========================================

  test "new renders form" do
    sign_in(@admin)
    get new_admin_scorecard_template_path

    assert_response :success
    assert_match "New Scorecard Template", response.body
    assert_select "form"
    assert_select "input[name='scorecards_template[name]']"
  end

  test "new form has scorecard-template-form stimulus controller" do
    sign_in(@admin)
    get new_admin_scorecard_template_path

    assert_response :success
    assert_select "[data-controller='scorecard-template-form']"
  end

  test "new form shows add category button" do
    sign_in(@admin)
    get new_admin_scorecard_template_path

    assert_response :success
    assert_match "Add Category", response.body
  end

  test "new form mentions free-form notes field" do
    sign_in(@admin)
    get new_admin_scorecard_template_path

    assert_response :success
    assert_match "free-form notes field", response.body
  end

  # ==========================================
  # Create
  # ==========================================

  test "create saves a new template with categories" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, 1 do
      post admin_scorecard_templates_path, params: {
        scorecards_template: {
          name: "Culture Fit",
          description: "Evaluate team fit",
          scorecard_template_categories_attributes: {
            "0" => {name: "Communication", sort_order: 0},
            "1" => {name: "Teamwork", sort_order: 1}
          }
        }
      }
    end

    assert_redirected_to admin_scorecard_templates_path
    assert_match "Culture Fit", flash[:notice]

    template = ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.find_by(name: "Culture Fit") }
    assert_equal 2, template.scorecard_template_categories.count
    assert_equal @company.id, template.company_id
  end

  test "create with blank name renders errors" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_scorecard_templates_path, params: {
        scorecards_template: {name: "", description: ""}
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with duplicate name renders errors" do
    sign_in(@admin)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_scorecard_templates_path, params: {
        scorecards_template: {name: "Technical Assessment"}
      }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects blank category names" do
    sign_in(@admin)

    post admin_scorecard_templates_path, params: {
      scorecards_template: {
        name: "New Template",
        scorecard_template_categories_attributes: {
          "0" => {name: "", sort_order: 0},
          "1" => {name: "Valid Category", sort_order: 1}
        }
      }
    }

    # Blank categories are rejected via reject_if proc
    assert_redirected_to admin_scorecard_templates_path
    template = ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.find_by(name: "New Template") }
    assert_equal 1, template.scorecard_template_categories.count
    assert_equal "Valid Category", template.scorecard_template_categories.first.name
  end

  test "interviewer cannot create template" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      post admin_scorecard_templates_path, params: {
        scorecards_template: {name: "Hacked Template"}
      }
    end

    assert_redirected_to tenant_root_path
  end

  test "hiring manager can create template" do
    sign_in(@hiring_manager)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, 1 do
      post admin_scorecard_templates_path, params: {
        scorecards_template: {
          name: "HM Template",
          scorecard_template_categories_attributes: {
            "0" => {name: "Leadership", sort_order: 0}
          }
        }
      }
    end

    assert_redirected_to admin_scorecard_templates_path
  end

  # ==========================================
  # Show
  # ==========================================

  test "show displays template with categories" do
    sign_in(@admin)
    get admin_scorecard_template_path(@template)

    assert_response :success
    assert_match "Technical Assessment", response.body
    assert_match "Problem Solving", response.body
    assert_match "1\u20135", response.body
  end

  test "show mentions automatic notes field" do
    sign_in(@admin)
    get admin_scorecard_template_path(@template)

    assert_response :success
    assert_match "free-form notes field", response.body
  end

  test "show displays description when present" do
    sign_in(@admin)
    get admin_scorecard_template_path(@template)

    assert_response :success
    assert_match "Evaluate technical skills", response.body
  end

  # ==========================================
  # Edit
  # ==========================================

  test "edit renders form with existing data" do
    sign_in(@admin)
    get edit_admin_scorecard_template_path(@template)

    assert_response :success
    assert_match "Edit Scorecard Template", response.body
    assert_select "input[name='scorecards_template[name]'][value='Technical Assessment']"
  end

  test "edit form has scorecard-template-form stimulus controller" do
    sign_in(@admin)
    get edit_admin_scorecard_template_path(@template)

    assert_response :success
    assert_select "[data-controller='scorecard-template-form']"
  end

  test "edit shows existing categories" do
    sign_in(@admin)
    get edit_admin_scorecard_template_path(@template)

    assert_response :success
    assert_select "input[value='Problem Solving']"
  end

  # ==========================================
  # Update
  # ==========================================

  test "update modifies template name" do
    sign_in(@admin)

    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {name: "Updated Assessment"}
    }

    assert_redirected_to admin_scorecard_template_path(@template)
    assert_match "updated", flash[:notice]

    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal "Updated Assessment", @template.name
  end

  test "update can add new categories" do
    sign_in(@admin)

    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, name: "Problem Solving", sort_order: 0},
          "1" => {name: "Code Quality", sort_order: 1}
        }
      }
    }

    assert_redirected_to admin_scorecard_template_path(@template)
    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal 2, @template.scorecard_template_categories.count
  end

  test "update can remove categories via _destroy" do
    sign_in(@admin)

    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, _destroy: "1"}
        }
      }
    }

    assert_redirected_to admin_scorecard_template_path(@template)
    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal 0, @template.scorecard_template_categories.count
  end

  test "update can reorder categories via sort_order" do
    sign_in(@admin)

    category2 = ActsAsTenant.with_tenant(@company) do
      ScorecardTemplateCategory.create!(
        scorecards_template: @template,
        name: "Code Quality",
        sort_order: 1
      )
    end

    # Swap order: Code Quality first, Problem Solving second
    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {
        scorecard_template_categories_attributes: {
          "0" => {id: @category.id, name: "Problem Solving", sort_order: 1},
          "1" => {id: category2.id, name: "Code Quality", sort_order: 0}
        }
      }
    }

    assert_redirected_to admin_scorecard_template_path(@template)
    ActsAsTenant.with_tenant(@company) do
      categories = @template.scorecard_template_categories.ordered
      assert_equal "Code Quality", categories.first.name
      assert_equal "Problem Solving", categories.last.name
    end
  end

  test "update with invalid data renders errors" do
    sign_in(@admin)

    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {name: ""}
    }

    assert_response :unprocessable_entity
  end

  # ==========================================
  # No editing restrictions
  # ==========================================

  test "can edit template freely with no restrictions" do
    sign_in(@admin)

    # First update
    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {name: "Renamed Once"}
    }
    assert_redirected_to admin_scorecard_template_path(@template)

    # Second update
    patch admin_scorecard_template_path(@template), params: {
      scorecards_template: {name: "Renamed Again", description: "New desc"}
    }
    assert_redirected_to admin_scorecard_template_path(@template)

    ActsAsTenant.with_tenant(@company) { @template.reload }
    assert_equal "Renamed Again", @template.name
    assert_equal "New desc", @template.description
  end

  # ==========================================
  # Destroy
  # ==========================================

  test "destroy deletes template and categories" do
    sign_in(@admin)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, -1 do
      delete admin_scorecard_template_path(@template)
    end

    assert_redirected_to admin_scorecard_templates_path
    assert_match "Technical Assessment", flash[:notice]

    # Categories should be destroyed too (dependent: :destroy)
    assert_equal 0, ScorecardTemplateCategory.where(scorecards_template_id: @template.id).count
  end

  test "interviewer cannot destroy template" do
    sign_in(@interviewer)

    assert_no_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } } do
      delete admin_scorecard_template_path(@template)
    end

    assert_redirected_to tenant_root_path
  end

  test "hiring manager can destroy template" do
    sign_in(@hiring_manager)

    assert_difference -> { ActsAsTenant.with_tenant(@company) { ScorecardsTemplate.count } }, -1 do
      delete admin_scorecard_template_path(@template)
    end

    assert_redirected_to admin_scorecard_templates_path
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "cannot access templates from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_template = ActsAsTenant.with_tenant(other_company) do
      ScorecardsTemplate.create!(company: other_company, name: "Other Template")
    end

    sign_in(@admin)

    get admin_scorecard_template_path(other_template)
    assert_response :not_found
  end

  test "cannot update templates from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_template = ActsAsTenant.with_tenant(other_company) do
      ScorecardsTemplate.create!(company: other_company, name: "Other Template")
    end

    sign_in(@admin)

    patch admin_scorecard_template_path(other_template), params: {
      scorecards_template: {name: "Hacked"}
    }
    assert_response :not_found
  end

  test "cannot delete templates from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_template = ActsAsTenant.with_tenant(other_company) do
      ScorecardsTemplate.create!(company: other_company, name: "Other Template")
    end

    sign_in(@admin)

    assert_no_difference -> { ScorecardsTemplate.unscoped.count } do
      delete admin_scorecard_template_path(other_template)
    end
    assert_response :not_found
  end

  # ==========================================
  # Fixed 1-5 rating scale
  # ==========================================

  test "show page displays 1-5 rating scale indicator" do
    sign_in(@admin)
    get admin_scorecard_template_path(@template)

    assert_response :success
    # The view shows "1–5" as the rating scale
    assert_match "1\u20135", response.body
  end

  test "form displays 1-5 rating scale indicator" do
    sign_in(@admin)
    get new_admin_scorecard_template_path

    assert_response :success
    assert_match "1-5 scale", response.body
  end
end
