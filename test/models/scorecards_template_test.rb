require "test_helper"

class ScorecardsTemplateTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp-st")
    ActsAsTenant.current_tenant = @company
    @role = Role.create!(company: @company, title: "Software Engineer")
    @phase = @role.interview_phases.first
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid scorecards template" do
    template = ScorecardsTemplate.new(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    assert template.valid?
  end

  test "requires name" do
    template = ScorecardsTemplate.new(
      company: @company,
      interview_phase: @phase,
      name: ""
    )
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires interview_phase" do
    template = ScorecardsTemplate.new(
      company: @company,
      interview_phase: nil,
      name: "Technical Assessment"
    )
    assert_not template.valid?
  end

  test "name must be unique within interview phase" do
    ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    duplicate = ScorecardsTemplate.new(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists for this interview phase"
  end

  test "same name allowed on different phases" do
    other_role = Role.create!(company: @company, title: "Product Manager")
    other_phase = other_role.interview_phases.first

    ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    template = ScorecardsTemplate.new(
      company: @company,
      interview_phase: other_phase,
      name: "Technical Assessment"
    )
    assert template.valid?
  end

  test "belongs to interview_phase" do
    template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    assert_equal @phase, template.interview_phase
  end

  test "has many scorecard_template_categories" do
    template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    cat1 = ScorecardTemplateCategory.create!(
      scorecards_template: template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    cat2 = ScorecardTemplateCategory.create!(
      scorecards_template: template,
      name: "Communication",
      rating_scale: 5,
      sort_order: 1
    )
    assert_equal 2, template.scorecard_template_categories.count
  end

  test "destroying template destroys categories" do
    template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
    ScorecardTemplateCategory.create!(
      scorecards_template: template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    assert_difference "ScorecardTemplateCategory.count", -1 do
      template.destroy!
    end
  end

  test "accepts nested attributes for categories" do
    template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment",
      scorecard_template_categories_attributes: [
        { name: "Problem Solving", rating_scale: 5, sort_order: 0 },
        { name: "Communication", rating_scale: 5, sort_order: 1 }
      ]
    )
    assert_equal 2, template.scorecard_template_categories.count
  end

  test "description is optional" do
    template = ScorecardsTemplate.new(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment",
      description: nil
    )
    assert template.valid?
  end

  test "description can be set" do
    template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment",
      description: "Evaluates core technical skills"
    )
    assert_equal "Evaluates core technical skills", template.description
  end

  test "interview_phase has_many scorecards_templates" do
    ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Template A"
    )
    ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Template B"
    )
    assert_equal 2, @phase.scorecards_templates.count
  end
end
