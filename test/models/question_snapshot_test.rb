# frozen_string_literal: true

require "test_helper"

class QuestionSnapshotTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Snapshot Co", subdomain: "snapco")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company,
      first_name: "Admin",
      last_name: "User",
      email: "admin-snap@snapco.com",
      role: "admin"
    )

    @role = Role.create!(company: @company, title: "Engineer", status: "draft")
    @role.interview_phases.first.update!(phase_owner: @admin)
    @role.update_column(:status, "published")

    @candidate = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane-snap@example.com"
    )

    @application = ApplicationSubmission.create!(
      company: @company,
      role: @role,
      candidate: @candidate,
      status: "applied",
      submitted_at: Time.current
    )

    @question = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Years of experience?",
      field_type: "text",
      position: 0,
      required: true
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # ==========================================
  # Validations
  # ==========================================

  test "valid snapshot" do
    snapshot = QuestionSnapshot.new(
      application_id: @application.id,
      custom_question: @question,
      company: @company,
      label: "Years of experience?",
      field_type: "text",
      required: true,
      answer: "5 years"
    )
    assert snapshot.valid?
  end

  test "requires label" do
    snapshot = QuestionSnapshot.new(
      application_id: @application.id,
      company: @company,
      label: nil,
      field_type: "text"
    )
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:label], "can't be blank"
  end

  test "requires field_type" do
    snapshot = QuestionSnapshot.new(
      application_id: @application.id,
      company: @company,
      label: "Test",
      field_type: nil
    )
    assert_not snapshot.valid?
  end

  # ==========================================
  # Snapshot preserves question data at submission time
  # ==========================================

  test "snapshot preserves original label even after question is updated" do
    snapshot = QuestionSnapshot.create!(
      application_id: @application.id,
      custom_question: @question,
      company: @company,
      label: @question.label,
      field_type: @question.field_type,
      required: @question.required,
      answer: "5 years"
    )

    # Update the original question
    @question.update!(label: "How many years have you worked?")

    # Snapshot retains original label
    snapshot.reload
    assert_equal "Years of experience?", snapshot.label
  end

  test "snapshot preserves options for select type" do
    select_q = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Level",
      field_type: "select",
      position: 1,
      options: ["Junior", "Mid", "Senior"]
    )

    snapshot = QuestionSnapshot.create!(
      application_id: @application.id,
      custom_question: select_q,
      company: @company,
      label: select_q.label,
      field_type: select_q.field_type,
      required: select_q.required,
      options: select_q.options,
      answer: "Senior"
    )

    # Update original question options
    select_q.update!(options: ["L1", "L2", "L3", "L4"])

    # Snapshot retains original options
    snapshot.reload
    assert_equal ["Junior", "Mid", "Senior"], snapshot.options
    assert_equal "Senior", snapshot.answer
  end

  # ==========================================
  # Snapshot survives question deletion
  # ==========================================

  test "snapshot survives when custom question is deleted (nullify)" do
    snapshot = QuestionSnapshot.create!(
      application_id: @application.id,
      custom_question: @question,
      company: @company,
      label: @question.label,
      field_type: @question.field_type,
      required: @question.required,
      answer: "5 years"
    )

    @question.destroy!

    snapshot.reload
    assert_nil snapshot.custom_question_id
    assert_equal "Years of experience?", snapshot.label
    assert_equal "5 years", snapshot.answer
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "snapshots are tenant-scoped" do
    snapshot = QuestionSnapshot.create!(
      application_id: @application.id,
      custom_question: @question,
      company: @company,
      label: @question.label,
      field_type: @question.field_type,
      required: @question.required,
      answer: "test"
    )

    other_company = Company.create!(name: "Other", subdomain: "othersnap")
    ActsAsTenant.current_tenant = other_company

    assert_not QuestionSnapshot.exists?(snapshot.id)

    ActsAsTenant.current_tenant = @company
    assert QuestionSnapshot.exists?(snapshot.id)
  end

  # ==========================================
  # Association
  # ==========================================

  test "belongs to application_submission" do
    snapshot = QuestionSnapshot.create!(
      application_id: @application.id,
      custom_question: @question,
      company: @company,
      label: @question.label,
      field_type: @question.field_type,
      required: @question.required,
      answer: "test"
    )
    assert_equal @application, snapshot.application_submission
  end

  test "custom_question is optional (allows nil after deletion)" do
    snapshot = QuestionSnapshot.new(
      application_id: @application.id,
      custom_question: nil,
      company: @company,
      label: "Deleted question",
      field_type: "text",
      required: false,
      answer: "answer"
    )
    assert snapshot.valid?
  end
end
