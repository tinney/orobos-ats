# frozen_string_literal: true

require "test_helper"

class Admin::MyInterviewsControllerTest < ActionDispatch::IntegrationTest
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
      @candidate = Candidate.create!(
        company: @company,
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com"
      )
      @application = ApplicationSubmission.create!(
        company: @company,
        candidate: @candidate,
        role: @role
      )
      @interview = Interview.create!(
        company: @company,
        application: @application,
        interview_phase: @phase
      )
      @interview.assign_interviewer!(@interviewer)
      @interview.assign_interviewer!(@second_interviewer)
    end

    host! "testcorp.example.com"
  end

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end

  # ==========================================
  # Index — my interviews listing
  # ==========================================

  test "interviewer sees their assigned interviews" do
    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    assert_match "Jane Doe", response.body
    assert_match "Software Engineer", response.body
    assert_match @phase.name, response.body
  end

  test "interviewer sees assignment role badge" do
    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    # Should see assignment role badge
    assert_match "Interviewer", response.body
  end

  test "interviewer sees interviews grouped by role" do
    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    # Should see role title as group header
    assert_match "Software Engineer", response.body
    # Should see interview count badge
    assert_match "1 interview", response.body
  end

  test "interviewer sees scheduled time in table" do
    ActsAsTenant.with_tenant(@company) do
      @interview.schedule!(2.days.from_now)
    end

    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    assert_match "Scheduled", response.body
  end

  test "interviewer sees submit scorecard link when no scorecard exists" do
    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    assert_match "Submit Scorecard", response.body
  end

  test "interviewer sees edit scorecard link when scorecard exists" do
    ActsAsTenant.with_tenant(@company) do
      Scorecard.create!(
        company: @company,
        interview: @interview,
        user: @interviewer,
        notes: "Good candidate"
      )
    end

    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    assert_match "Edit Scorecard", response.body
  end

  test "second interviewer sees the same interview in table" do
    ActsAsTenant.with_tenant(@company) do
      @interview.schedule!(2.days.from_now)
    end

    sign_in @second_interviewer

    get admin_my_interviews_path

    assert_response :success
    # Second interviewer should see the same interview
    assert_match "Scheduled", response.body
    assert_match "Jane Doe", response.body
    assert_match "Interviewer", response.body
  end

  test "empty state when no interviews assigned" do
    ActsAsTenant.with_tenant(@company) do
      InterviewParticipant.where(user: @interviewer).destroy_all
    end

    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    assert_match "No interviews assigned", response.body
  end

  test "unauthenticated user cannot access my interviews" do
    get admin_my_interviews_path

    assert_response :redirect
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "interviewer does not see interviews from other tenants" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      other_interviewer = User.create!(
        company: other_company,
        email: "ivan@othercorp.com",
        first_name: "Ivan",
        last_name: "Other",
        role: "interviewer"
      )
      other_role = Role.create!(company: other_company, title: "Other Role")
      other_candidate = Candidate.create!(
        company: other_company,
        first_name: "Bob",
        last_name: "Other",
        email: "bob@example.com"
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
      other_interview.assign_interviewer!(other_interviewer)
    end

    sign_in @interviewer

    get admin_my_interviews_path

    assert_response :success
    # Should only see own tenant's interviews
    assert_match "Jane Doe", response.body
    assert_no_match(/Bob Other/, response.body)
  end
end
