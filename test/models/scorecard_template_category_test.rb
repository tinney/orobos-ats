require "test_helper"

class ScorecardTemplateCategoryTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp-stc")
    ActsAsTenant.current_tenant = @company
    @role = Role.create!(company: @company, title: "Software Engineer")
    @phase = @role.interview_phases.first
    @template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Technical Assessment"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid category" do
    category = ScorecardTemplateCategory.new(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    assert category.valid?
  end

  test "requires name" do
    category = ScorecardTemplateCategory.new(
      scorecards_template: @template,
      name: "",
      rating_scale: 5,
      sort_order: 0
    )
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "requires rating_scale" do
    category = ScorecardTemplateCategory.new(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: nil,
      sort_order: 0
    )
    assert_not category.valid?
  end

  test "rating_scale must be between 1 and 5" do
    [0, 6, -1, 10].each do |invalid_scale|
      category = ScorecardTemplateCategory.new(
        scorecards_template: @template,
        name: "Problem Solving",
        rating_scale: invalid_scale,
        sort_order: 0
      )
      assert_not category.valid?, "rating_scale #{invalid_scale} should be invalid"
      assert_includes category.errors[:rating_scale], "must be between 1 and 5"
    end
  end

  test "rating_scale accepts valid values 1 through 5" do
    (1..5).each do |valid_scale|
      category = ScorecardTemplateCategory.new(
        scorecards_template: @template,
        name: "Category #{valid_scale}",
        rating_scale: valid_scale,
        sort_order: valid_scale
      )
      assert category.valid?, "rating_scale #{valid_scale} should be valid"
    end
  end

  test "name must be unique within template" do
    ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    duplicate = ScorecardTemplateCategory.new(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 1
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists for this template"
  end

  test "same name allowed on different templates" do
    other_template = ScorecardsTemplate.create!(
      company: @company,
      interview_phase: @phase,
      name: "Behavioral Assessment"
    )

    ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Communication",
      rating_scale: 5,
      sort_order: 0
    )
    category = ScorecardTemplateCategory.new(
      scorecards_template: other_template,
      name: "Communication",
      rating_scale: 5,
      sort_order: 0
    )
    assert category.valid?
  end

  test "sort_order must be non-negative integer" do
    category = ScorecardTemplateCategory.new(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: -1
    )
    assert_not category.valid?
  end

  test "ordered scope sorts by sort_order" do
    cat2 = ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Communication",
      rating_scale: 5,
      sort_order: 2
    )
    cat0 = ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    cat1 = ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Technical Skills",
      rating_scale: 5,
      sort_order: 1
    )
    ordered = @template.scorecard_template_categories.ordered
    assert_equal [cat0, cat1, cat2], ordered.to_a
  end

  test "belongs to scorecards_template" do
    category = ScorecardTemplateCategory.create!(
      scorecards_template: @template,
      name: "Problem Solving",
      rating_scale: 5,
      sort_order: 0
    )
    assert_equal @template, category.scorecards_template
  end

  test "default rating_scale is 5" do
    category = ScorecardTemplateCategory.new(scorecards_template: @template, name: "Test", sort_order: 0)
    assert_equal 5, category.rating_scale
  end
end
