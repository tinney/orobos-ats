# frozen_string_literal: true

require "test_helper"

class Admin::CandidatesControllerTest < ActionDispatch::IntegrationTest
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
      @role1 = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "published"
      )
      @role2 = Role.create!(
        company: @company,
        title: "Product Manager",
        status: "published"
      )
      @candidate1 = Candidate.create!(
        company: @company,
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com"
      )
      @candidate2 = Candidate.create!(
        company: @company,
        first_name: "Bob",
        last_name: "Smith",
        email: "bob@example.com"
      )
      @app1 = ApplicationSubmission.create!(
        company: @company,
        candidate: @candidate1,
        role: @role1,
        status: "applied"
      )
      @app2 = ApplicationSubmission.create!(
        company: @company,
        candidate: @candidate2,
        role: @role2,
        status: "interviewing"
      )
    end

    host! "testcorp.example.com"
  end

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  # ==========================================
  # Index — global candidates list
  # ==========================================

  test "admin can access candidates index" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "All Candidates", response.body
    assert_match "Jane Doe", response.body
    assert_match "Bob Smith", response.body
  end

  test "hiring manager can access candidates index" do
    sign_in @hiring_manager

    get admin_candidates_path

    assert_response :success
    assert_match "Jane Doe", response.body
    assert_match "Bob Smith", response.body
  end

  test "interviewer cannot access candidates index" do
    sign_in @interviewer

    get admin_candidates_path

    assert_response :redirect
  end

  test "unauthenticated user cannot access candidates index" do
    get admin_candidates_path

    assert_response :redirect
  end

  test "index shows applications from multiple roles" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "Software Engineer", response.body
    assert_match "Product Manager", response.body
  end

  test "index renders stimulus controller data attributes" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match 'data-controller="candidates-list"', response.body
    assert_match 'data-candidates-list-target="roleFilter"', response.body
    assert_match 'data-candidates-list-target="statusFilter"', response.body
    assert_match 'data-candidates-list-target="row"', response.body
    assert_match 'data-candidates-list-target="table"', response.body
  end

  test "index renders sortable column headers" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match 'data-action="click->candidates-list#sort"', response.body
    assert_match 'data-sort-column="candidateName"', response.body
    assert_match 'data-sort-column="appliedAt"', response.body
  end

  test "index renders view toggle buttons" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "Flat List", response.body
    assert_match "Grouped by Role", response.body
  end

  test "index renders role filter with available roles" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "All Roles", response.body
    assert_match "Software Engineer", response.body
    assert_match "Product Manager", response.body
  end

  test "index renders status filter with all statuses" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "All Statuses", response.body
    assert_match "Applied", response.body
    assert_match "Interviewing", response.body
  end

  test "rows include data attributes for client-side filtering" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    # Check data attributes for filtering
    assert_match "data-role=\"#{@role1.id}\"", response.body
    assert_match "data-status=\"applied\"", response.body
    assert_match "data-status=\"interviewing\"", response.body
    assert_match "data-candidate-name=\"Jane Doe\"", response.body
  end

  test "index shows bot warning flags" do
    ActsAsTenant.with_tenant(@company) do
      @app1.update!(bot_flagged: true, bot_dismissed: false)
    end

    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "Bot", response.body
  end

  test "index shows status badges with color coding" do
    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "bg-blue-100", response.body   # applied
    assert_match "bg-yellow-100", response.body  # interviewing
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "candidates index does not show other tenant data" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      other_candidate = Candidate.create!(
        company: other_company,
        first_name: "Zara",
        last_name: "Other",
        email: "zara@other.com"
      )
      other_role = Role.create!(company: other_company, title: "Other Role")
      ApplicationSubmission.create!(
        company: other_company,
        candidate: other_candidate,
        role: other_role,
        status: "applied"
      )
    end

    sign_in @admin

    get admin_candidates_path

    assert_response :success
    assert_match "Jane Doe", response.body
    assert_no_match(/Zara Other/, response.body)
    assert_no_match(/Other Role/, response.body)
  end
end
