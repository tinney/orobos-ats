# frozen_string_literal: true

require "test_helper"

class CustomQuestionTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Co", subdomain: "testco")
    ActsAsTenant.current_tenant = @company

    @role = Role.create!(
      company: @company,
      title: "Software Engineer",
      status: "draft"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # ==========================================
  # Validations
  # ==========================================

  test "valid custom question with text type" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Years of experience?",
      field_type: "text",
      position: 0
    )
    assert q.valid?
  end

  test "valid custom question with textarea type" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Tell us about yourself",
      field_type: "textarea",
      position: 1
    )
    assert q.valid?
  end

  test "valid custom question with select type and options" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Experience level",
      field_type: "select",
      position: 0,
      required: true,
      options: ["Junior", "Mid", "Senior"]
    )
    assert q.valid?
    assert_equal ["Junior", "Mid", "Senior"], q.options
  end

  test "requires label" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: nil,
      field_type: "text",
      position: 0
    )
    assert_not q.valid?
    assert_includes q.errors[:label], "can't be blank"
  end

  test "requires field_type" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Question",
      field_type: nil,
      position: 0
    )
    assert_not q.valid?
  end

  test "rejects invalid field_type" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Question",
      field_type: "checkbox",
      position: 0
    )
    assert_not q.valid?
    assert_includes q.errors[:field_type], "is not included in the list"
  end

  test "requires position" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Question",
      field_type: "text",
      position: nil
    )
    assert_not q.valid?
  end

  test "position must be non-negative integer" do
    q = CustomQuestion.new(
      company: @company,
      role: @role,
      label: "Question",
      field_type: "text",
      position: -1
    )
    assert_not q.valid?
  end

  # ==========================================
  # Associations
  # ==========================================

  test "belongs to role" do
    q = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Test?",
      field_type: "text",
      position: 0
    )
    assert_equal @role, q.role
  end

  test "belongs to company" do
    q = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Test?",
      field_type: "text",
      position: 0
    )
    assert_equal @company, q.company
  end

  test "has many question_snapshots" do
    q = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Test?",
      field_type: "text",
      position: 0
    )
    assert_respond_to q, :question_snapshots
  end

  # ==========================================
  # Scopes
  # ==========================================

  test "ordered scope returns questions by position ascending" do
    q2 = CustomQuestion.create!(company: @company, role: @role, label: "Second", field_type: "text", position: 1)
    q1 = CustomQuestion.create!(company: @company, role: @role, label: "First", field_type: "text", position: 0)
    q3 = CustomQuestion.create!(company: @company, role: @role, label: "Third", field_type: "textarea", position: 2)

    ordered = @role.custom_questions.ordered
    assert_equal [q1, q2, q3], ordered.to_a
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "custom questions are tenant-scoped" do
    q = CustomQuestion.create!(company: @company, role: @role, label: "Tenant Q", field_type: "text", position: 0)

    other_company = Company.create!(name: "Other Co", subdomain: "other")
    ActsAsTenant.current_tenant = other_company

    assert_not CustomQuestion.exists?(q.id)

    ActsAsTenant.current_tenant = @company
    assert CustomQuestion.exists?(q.id)
  end

  # ==========================================
  # Role association - custom_questions destroyed with role
  # ==========================================

  test "destroying role destroys associated custom questions" do
    CustomQuestion.create!(company: @company, role: @role, label: "Q1", field_type: "text", position: 0)
    CustomQuestion.create!(company: @company, role: @role, label: "Q2", field_type: "textarea", position: 1)
    assert_equal 2, @role.custom_questions.count

    @role.destroy!
    assert_equal 0, CustomQuestion.count
  end

  # ==========================================
  # Required field
  # ==========================================

  test "required defaults to false" do
    q = CustomQuestion.create!(company: @company, role: @role, label: "Optional Q", field_type: "text", position: 0)
    assert_equal false, q.required
  end

  test "required can be set to true" do
    q = CustomQuestion.create!(company: @company, role: @role, label: "Required Q", field_type: "text", position: 0, required: true)
    assert_equal true, q.required
    assert q.required?
  end

  # ==========================================
  # Options (JSONB)
  # ==========================================

  test "options defaults to empty array" do
    q = CustomQuestion.create!(company: @company, role: @role, label: "Q", field_type: "text", position: 0)
    assert_equal [], q.options
  end

  test "options stores array of strings for select type" do
    q = CustomQuestion.create!(
      company: @company,
      role: @role,
      label: "Preferred stack",
      field_type: "select",
      position: 0,
      options: ["Ruby", "Python", "Go", "Rust"]
    )
    q.reload
    assert_equal ["Ruby", "Python", "Go", "Rust"], q.options
  end

  # ==========================================
  # Multiple questions per role
  # ==========================================

  test "role can have multiple custom questions" do
    3.times do |i|
      CustomQuestion.create!(
        company: @company,
        role: @role,
        label: "Question #{i + 1}",
        field_type: %w[text textarea select][i],
        position: i
      )
    end
    assert_equal 3, @role.custom_questions.count
  end
end
