# frozen_string_literal: true

require "test_helper"

class ApplicationSubmissionServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @company = Company.create!(name: "Test Co", subdomain: "testco")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company,
      first_name: "Admin",
      last_name: "User",
      email: "admin@testco.com",
      role: "admin"
    )

    @role = Role.create!(company: @company, title: "Engineer")
    @role.interview_phases.first.update!(phase_owner: @admin)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "creates candidate and application on success" do
    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      phone: "555-0123",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?
    assert_not_nil result.application

    candidate = result.application.candidate
    assert_equal "jane@example.com", candidate.email
    assert_equal "Jane", candidate.first_name
    assert_equal "Doe", candidate.last_name
    assert_equal "555-0123", candidate.phone

    assert_equal "applied", result.application.status
    assert_equal @role, result.application.role
    assert_equal @company, result.application.company
    assert_not_nil result.application.submitted_at
  end

  test "saves cover letter on application" do
    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      cover_letter: "I love this role!",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?
    assert_equal "I love this role!", result.application.cover_letter
  end

  test "blank cover letter is stored as nil" do
    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      cover_letter: "   ",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?
    assert_nil result.application.cover_letter
  end

  test "reuses existing candidate with same email" do
    existing = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )

    params = {
      first_name: "Janet",
      last_name: "Doe",
      email: "jane@example.com",
      phone: "555-9999",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    assert_no_difference "Candidate.count" do
      result = ApplicationSubmissionService.new(
        role: @role,
        company: @company,
        params: params
      ).call

      assert result.success?
      assert_equal existing.id, result.application.candidate_id
    end
  end

  test "snapshots custom questions with answers" do
    q1 = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Years of experience?",
      field_type: "text",
      position: 0,
      required: true
    )
    q2 = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Preferred language?",
      field_type: "select",
      position: 1,
      required: false,
      options: ["Ruby", "Python", "Go"]
    )

    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      form_loaded_at: 10.seconds.ago.iso8601,
      custom_answers: {
        "custom_question_#{q1.id}" => "5 years",
        "custom_question_#{q2.id}" => "Ruby"
      }
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?

    snapshots = result.application.question_snapshots.order(:label)
    assert_equal 2, snapshots.count

    snap1 = snapshots.find_by(label: "Preferred language?")
    assert_equal "select", snap1.field_type
    assert_equal "Ruby", snap1.answer
    assert_equal ["Ruby", "Python", "Go"], snap1.options

    snap2 = snapshots.find_by(label: "Years of experience?")
    assert_equal "text", snap2.field_type
    assert_equal "5 years", snap2.answer
    assert snap2.required
  end

  test "runs bot detection and stores results" do
    params = {
      first_name: "Bot",
      last_name: "User",
      email: "bot@example.com",
      website: "http://spam.com",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?
    assert result.application.bot_flagged?
    assert result.application.honeypot_filled?
    assert_includes result.application.bot_reasons, "honeypot_filled"
    assert result.application.bot_score > 0
  end

  test "non-bot submission is not flagged" do
    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert result.success?
    assert_not result.application.bot_flagged?
    assert_not result.application.honeypot_filled?
  end

  test "sends confirmation email" do
    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    assert_enqueued_emails 1 do
      result = ApplicationSubmissionService.new(
        role: @role,
        company: @company,
        params: params
      ).call

      assert result.success?
    end
  end

  test "returns error when candidate data is invalid" do
    params = {
      first_name: "",
      last_name: "",
      email: "",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert_not result.success?
    assert result.errors.any?
  end

  test "returns error for duplicate application" do
    Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )

    params = {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      form_loaded_at: 10.seconds.ago.iso8601
    }

    # First submission
    ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    # Second submission should fail
    result = ApplicationSubmissionService.new(
      role: @role,
      company: @company,
      params: params
    ).call

    assert_not result.success?
    assert result.errors.any?
  end
end
