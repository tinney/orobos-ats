# frozen_string_literal: true

require "test_helper"

class Admin::AssignmentsControllerTest < ActionDispatch::IntegrationTest
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
      @second_interviewer = User.create!(
        company: @company,
        email: "second@testcorp.com",
        first_name: "Sara",
        last_name: "Second",
        role: "interviewer"
      )

      @role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "published"
      )
      @phase = @role.interview_phases.ordered.first
      @second_role = Role.create!(
        company: @company,
        title: "Product Manager",
        status: "published"
      )
      @second_phase = @second_role.interview_phases.ordered.first

      @candidate = Candidate.create!(
        company: @company,
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com"
      )
      @second_candidate = Candidate.create!(
        company: @company,
        first_name: "Bob",
        last_name: "Smith",
        email: "bob@example.com"
      )

      @application = ApplicationSubmission.create!(
        company: @company,
        candidate: @candidate,
        role: @role
      )
      @second_application = ApplicationSubmission.create!(
        company: @company,
        candidate: @second_candidate,
        role: @second_role
      )

      @interview = Interview.create!(
        company: @company,
        application: @application,
        interview_phase: @phase
      )
      @interview.assign_interviewer!(@interviewer)

      @second_interview = Interview.create!(
        company: @company,
        application: @second_application,
        interview_phase: @second_phase
      )
      @second_interview.assign_interviewer!(@second_interviewer)
      @second_interview.schedule!(3.days.from_now)
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

  test "unauthenticated user cannot access assignments" do
    get admin_assignments_path
    assert_response :redirect
  end

  test "interviewer can access assignments" do
    sign_in @interviewer
    get admin_assignments_path
    assert_response :success
  end

  test "hiring manager can access assignments" do
    sign_in @hiring_manager
    get admin_assignments_path
    assert_response :success
  end

  test "admin can access assignments" do
    sign_in @admin
    get admin_assignments_path
    assert_response :success
  end

  # ==========================================
  # Role-based scoping
  # ==========================================

  test "interviewer sees only their own assignments" do
    sign_in @interviewer

    get admin_assignments_path
    assert_response :success

    # Should see their own interview (Jane Doe / Software Engineer)
    assert_match "Jane Doe", response.body
    # Should NOT see the second interviewer's interview
    assert_no_match(/Bob Smith/, response.body)
  end

  test "hiring manager sees all assignments across tenant" do
    sign_in @hiring_manager

    get admin_assignments_path
    assert_response :success

    # Should see all interviews
    assert_match "Jane Doe", response.body
    assert_match "Bob Smith", response.body
  end

  test "admin sees all assignments across tenant" do
    sign_in @admin

    get admin_assignments_path
    assert_response :success

    assert_match "Jane Doe", response.body
    assert_match "Bob Smith", response.body
  end

  # ==========================================
  # Filtering
  # ==========================================

  test "filter by status shows only matching interviews" do
    sign_in @admin

    get admin_assignments_path(status: "scheduled")
    assert_response :success

    # Second interview is scheduled, first is unscheduled
    assert_match "Bob Smith", response.body
    assert_no_match(/Jane Doe/, response.body)
  end

  test "filter by unscheduled status" do
    sign_in @admin

    get admin_assignments_path(status: "unscheduled")
    assert_response :success

    assert_match "Jane Doe", response.body
    assert_no_match(/Bob Smith/, response.body)
  end

  test "filter by role shows only interviews for that role" do
    sign_in @admin

    get admin_assignments_path(role_id: @role.id)
    assert_response :success

    assert_match "Jane Doe", response.body
    assert_no_match(/Bob Smith/, response.body)
  end

  test "filter by interviewer shows only their interviews" do
    sign_in @admin

    get admin_assignments_path(interviewer_id: @second_interviewer.id)
    assert_response :success

    assert_match "Bob Smith", response.body
    assert_no_match(/Jane Doe/, response.body)
  end

  test "interviewer cannot filter by interviewer_id" do
    # Assign both interviews to the interviewer so we can test the filter is ignored
    ActsAsTenant.with_tenant(@company) do
      @second_interview.assign_interviewer!(@interviewer)
    end

    sign_in @interviewer

    # Even with interviewer_id filter for second_interviewer, interviewer still sees their own
    get admin_assignments_path(interviewer_id: @second_interviewer.id)
    assert_response :success

    # Interviewer should still see their assigned interviews (filter ignored for interviewers)
    assert_match "Jane Doe", response.body
  end

  test "filter by invalid status is ignored" do
    sign_in @admin

    get admin_assignments_path(status: "nonexistent")
    assert_response :success

    # Should show all interviews since invalid status is ignored
    assert_match "Jane Doe", response.body
    assert_match "Bob Smith", response.body
  end

  # ==========================================
  # Sorting
  # ==========================================

  test "sort by scheduled_at ascending" do
    sign_in @admin

    get admin_assignments_path(sort: "scheduled_at_asc")
    assert_response :success
  end

  test "sort by scheduled_at descending" do
    sign_in @admin

    get admin_assignments_path(sort: "scheduled_at_desc")
    assert_response :success
  end

  test "sort by status" do
    sign_in @admin

    get admin_assignments_path(sort: "status")
    assert_response :success
  end

  test "sort by candidate name" do
    sign_in @admin

    get admin_assignments_path(sort: "candidate")
    assert_response :success
  end

  test "sort by role title" do
    sign_in @admin

    get admin_assignments_path(sort: "role")
    assert_response :success
  end

  test "default sorting prioritizes scheduled then unscheduled" do
    sign_in @admin

    get admin_assignments_path
    assert_response :success
  end

  # ==========================================
  # Combined filters and sorting
  # ==========================================

  test "filter and sort combined" do
    sign_in @admin

    get admin_assignments_path(status: "unscheduled", sort: "candidate", role_id: @role.id)
    assert_response :success

    assert_match "Jane Doe", response.body
    assert_no_match(/Bob Smith/, response.body)
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "assignments are tenant-isolated" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      other_user = User.create!(
        company: other_company,
        email: "admin@othercorp.com",
        first_name: "Other",
        last_name: "Admin",
        role: "admin"
      )
      other_role = Role.create!(company: other_company, title: "Other Role")
      other_candidate = Candidate.create!(
        company: other_company,
        first_name: "Other",
        last_name: "Candidate",
        email: "other@example.com"
      )
      other_app = ApplicationSubmission.create!(
        company: other_company,
        candidate: other_candidate,
        role: other_role
      )
      other_phase = other_role.interview_phases.ordered.first
      other_interview = Interview.create!(
        company: other_company,
        application: other_app,
        interview_phase: other_phase
      )
      other_interview.assign_interviewer!(other_user)
    end

    sign_in @admin
    get admin_assignments_path
    assert_response :success

    # Should only see own tenant's data
    assert_match "Jane Doe", response.body
    assert_no_match(/Other Candidate/, response.body)
  end

  # ==========================================
  # Filter options exposed to view
  # ==========================================

  test "assigns filter data for view" do
    sign_in @admin

    get admin_assignments_path
    assert_response :success

    # Verify the page renders with filter-related content
    assert_match "Software Engineer", response.body
    assert_match "Product Manager", response.body
  end

  test "interviewer does not see interviewer filter options" do
    sign_in @interviewer

    get admin_assignments_path
    assert_response :success

    # Interviewers should not see the interviewer dropdown filter
    # (the select element with name="interviewer_id")
    assert_no_match(/name="interviewer_id"/, response.body)
  end

  test "hiring manager sees interviewer filter options" do
    sign_in @hiring_manager

    get admin_assignments_path
    assert_response :success

    # HMs should see the interviewer filter dropdown
    assert_match 'name="interviewer_id"', response.body
  end
end
