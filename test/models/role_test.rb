require "test_helper"

class RoleTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.current_tenant = @company
    @owner = User.create!(
      company: @company,
      email: "owner@testcorp.com",
      first_name: "Jane",
      last_name: "Owner",
      role: "hiring_manager"
    )
    @role = Role.create!(
      company: @company,
      title: "Software Engineer",
      description: "Build great software",
      location: "San Francisco, CA",
      remote: true,
      salary_min: 100_000,
      salary_max: 150_000,
      salary_currency: "USD"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Validations ---

  test "valid role with all attributes" do
    assert @role.valid?
  end

  test "valid role with only required attributes" do
    role = Role.new(company: @company, title: "Designer")
    assert role.valid?
  end

  test "requires title" do
    @role.title = nil
    assert_not @role.valid?
    assert_includes @role.errors[:title], "can't be blank"
  end

  test "requires status" do
    @role.status = nil
    assert_not @role.valid?
    assert_includes @role.errors[:status], "can't be blank"
  end

  test "status must be one of draft, published, internal_only, closed" do
    %w[draft published internal_only closed].each do |valid_status|
      @role.status = valid_status
      assert @role.valid?, "Expected #{valid_status} to be valid"
    end

    @role.status = "open"
    assert_not @role.valid?
    assert_includes @role.errors[:status], "is not included in the list"
  end

  test "default status is draft" do
    role = Role.create!(company: @company, title: "New Role")
    assert_equal "draft", role.status
  end

  test "default remote is false" do
    role = Role.create!(company: @company, title: "New Role")
    assert_equal false, role.remote
  end

  test "salary_min must be non-negative integer when present" do
    @role.salary_min = -1
    assert_not @role.valid?
    assert @role.errors[:salary_min].any?
  end

  test "salary_max must be non-negative integer when present" do
    @role.salary_max = -1
    assert_not @role.valid?
    assert @role.errors[:salary_max].any?
  end

  test "salary_min can be nil" do
    @role.salary_min = nil
    assert @role.valid?
  end

  test "salary_max can be nil" do
    @role.salary_max = nil
    assert @role.valid?
  end

  test "salary_max must be greater than or equal to salary_min" do
    @role.salary_min = 100_000
    @role.salary_max = 50_000
    assert_not @role.valid?
    assert_includes @role.errors[:salary_max], "must be greater than or equal to minimum salary"
  end

  test "salary_max can equal salary_min" do
    @role.salary_min = 100_000
    @role.salary_max = 100_000
    assert @role.valid?
  end

  # --- Slug generation ---

  test "slug is auto-generated from title" do
    role = Role.create!(company: @company, title: "Senior Product Designer")
    assert_equal "senior-product-designer", role.slug
  end

  test "slug is unique within company" do
    role2 = Role.create!(company: @company, title: "Software Engineer")
    assert_equal "software-engineer-2", role2.slug
  end

  test "slug is regenerated when title changes" do
    @role.update!(title: "Staff Engineer")
    assert_equal "staff-engineer", @role.slug
  end

  test "slug uniqueness is scoped to company" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      role = Role.create!(company: other_company, title: "Software Engineer")
      assert_equal "software-engineer", role.slug
    end
  end

  # --- Status helpers ---

  test "draft? returns true for draft status" do
    @role.status = "draft"
    assert @role.draft?
    assert_not @role.published?
  end

  test "published? returns true for published status" do
    @role.status = "published"
    assert @role.published?
    assert_not @role.draft?
  end

  test "internal_only? returns true for internal_only status" do
    @role.status = "internal_only"
    assert @role.internal_only?
  end

  test "closed? returns true for closed status" do
    @role.status = "closed"
    assert @role.closed?
  end

  # --- Scopes ---

  test "published scope returns only published roles" do
    draft_role = @role
    published_role = Role.create!(company: @company, title: "Published Role", status: "published")

    results = Role.published
    assert_includes results, published_role
    assert_not_includes results, draft_role
  end

  test "draft scope returns only draft roles" do
    draft_role = @role
    published_role = Role.create!(company: @company, title: "Published Role", status: "published")

    results = Role.draft
    assert_includes results, draft_role
    assert_not_includes results, published_role
  end

  # --- Salary range display ---

  test "salary_range returns formatted range when both min and max present" do
    assert_equal "USD 100,000–150,000", @role.salary_range
  end

  test "salary_range returns min+ when only min present" do
    @role.salary_max = nil
    assert_equal "USD 100,000+", @role.salary_range
  end

  test "salary_range returns up to max when only max present" do
    @role.salary_min = nil
    assert_equal "Up to USD 150,000", @role.salary_range
  end

  test "salary_range returns nil when neither present" do
    @role.salary_min = nil
    @role.salary_max = nil
    assert_nil @role.salary_range
  end

  # --- Tenant scoping ---

  test "role belongs to company" do
    assert_equal @company, @role.company
  end

  test "roles are scoped to current tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Other Role")
      assert_equal 1, Role.count
    end

    # Original tenant should not see the other role
    assert_equal 1, Role.count
  end

  test "company has_many roles" do
    assert_includes @company.roles, @role
  end

  # --- State transition guards ---

  test "can_publish? is true for draft with phase owner" do
    @role.status = "draft"
    assign_phase_owner(@role)
    assert @role.can_publish?
  end

  test "can_publish? is false for draft without phase owner" do
    @role.status = "draft"
    assert_not @role.can_publish?
  end

  test "can_publish? is true for internal_only with phase owner" do
    @role.status = "internal_only"
    assign_phase_owner(@role)
    assert @role.can_publish?
  end

  test "can_publish? is false for published" do
    @role.status = "published"
    assert_not @role.can_publish?
  end

  test "can_publish? is false for closed" do
    @role.status = "closed"
    assert_not @role.can_publish?
  end

  # --- Publishability ---

  test "publishable? is false when no phases have owners" do
    assert_not @role.publishable?
  end

  test "publishable? is true when at least one phase has an owner" do
    assign_phase_owner(@role)
    assert @role.publishable?
  end

  test "publishable? ignores archived phases" do
    phase = @role.interview_phases.active.first
    phase.update!(phase_owner: @owner)
    phase.archive!
    assert_not @role.publishable?
  end

  test "can_make_internal_only? is true for published" do
    @role.status = "published"
    assert @role.can_make_internal_only?
  end

  test "can_make_internal_only? is true for draft" do
    @role.status = "draft"
    assert @role.can_make_internal_only?
  end

  test "can_make_internal_only? is false for closed" do
    @role.status = "closed"
    assert_not @role.can_make_internal_only?
  end

  test "can_close? is true for published" do
    @role.status = "published"
    assert @role.can_close?
  end

  test "can_close? is true for internal_only" do
    @role.status = "internal_only"
    assert @role.can_close?
  end

  test "can_close? is false for draft" do
    @role.status = "draft"
    assert_not @role.can_close?
  end

  test "can_close? is false for closed" do
    @role.status = "closed"
    assert_not @role.can_close?
  end

  test "can_transition_to? works with string argument" do
    @role.status = "draft"
    assert @role.can_transition_to?("published")
    assert_not @role.can_transition_to?("closed")
  end

  test "can_transition_to? works with symbol argument" do
    @role.status = "draft"
    assert @role.can_transition_to?(:published)
  end

  # --- State transition methods ---

  test "publish! transitions draft to published when publishable" do
    assign_phase_owner(@role)
    @role.status = "draft"
    @role.save!
    @role.publish!
    assert_equal "published", @role.reload.status
  end

  test "publish! raises for draft role without phase owner" do
    @role.status = "draft"
    @role.save!
    assert_raises(ActiveRecord::RecordInvalid) { @role.publish! }
    assert_equal "draft", @role.reload.status
  end

  test "publish! transitions internal_only to published when publishable" do
    assign_phase_owner(@role)
    @role.update!(status: "published")
    @role.update!(status: "internal_only")
    @role.publish!
    assert_equal "published", @role.reload.status
  end

  test "publish! raises for closed role" do
    @role.update!(status: "published")
    @role.update!(status: "closed")
    assert_raises(ActiveRecord::RecordInvalid) { @role.publish! }
    assert_equal "closed", @role.reload.status
  end

  test "make_internal_only! transitions published to internal_only" do
    @role.update!(status: "published")
    @role.make_internal_only!
    assert_equal "internal_only", @role.reload.status
  end

  test "make_internal_only! succeeds for draft role" do
    @role.make_internal_only!
    assert_equal "internal_only", @role.reload.status
  end

  test "close! transitions published to closed" do
    @role.update!(status: "published")
    @role.close!
    assert_equal "closed", @role.reload.status
  end

  test "close! transitions internal_only to closed" do
    @role.update!(status: "published")
    @role.update!(status: "internal_only")
    @role.close!
    assert_equal "closed", @role.reload.status
  end

  test "close! raises for draft role" do
    assert_raises(ActiveRecord::RecordInvalid) { @role.close! }
    assert_equal "draft", @role.reload.status
  end

  test "transition_to! sets error message on invalid transition" do
    @role.update!(status: "published")
    @role.update!(status: "closed")
    error = assert_raises(ActiveRecord::RecordInvalid) { @role.transition_to!("published") }
    assert_match(/cannot transition from closed to published/, error.message)
  end

  test "closed role can only revert to draft" do
    @role.update!(status: "published")
    @role.update!(status: "closed")
    assert_equal %w[draft], Role::TRANSITIONS["closed"]
    assert_not @role.can_publish?
    assert_not @role.can_make_internal_only?
    assert_not @role.can_close?
    assert @role.can_transition_to?("draft")
  end

  # --- STATUSES constant ---

  test "STATUSES constant contains all valid statuses" do
    assert_equal %w[draft published internal_only closed], Role::STATUSES
  end

  test "TRANSITIONS covers all statuses" do
    assert_equal Role::STATUSES.sort, Role::TRANSITIONS.keys.sort
  end

  test "transition_to! published raises without phase owner" do
    error = assert_raises(ActiveRecord::RecordInvalid) { @role.transition_to!("published") }
    assert_match(/at least one interview phase must have a phase owner/, error.message)
    assert_equal "draft", @role.reload.status
  end

  test "transition_to! published succeeds with phase owner" do
    assign_phase_owner(@role)
    @role.transition_to!("published")
    assert_equal "published", @role.reload.status
  end

  private

  def assign_phase_owner(role)
    phase = role.interview_phases.active.first
    phase.update!(phase_owner: @owner)
  end
end

# ==========================================
# Preview Token (appended)
# ==========================================

class RolePreviewTokenTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Preview Corp", subdomain: "previewcorp")
    ActsAsTenant.current_tenant = @company
    @role = Role.create!(
      company: @company,
      title: "Preview Role",
      status: "draft"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "generate_preview_token! sets and returns a token" do
    token = @role.generate_preview_token!
    assert token.present?
    assert_equal token, @role.reload.preview_token
  end

  test "generate_preview_token! creates unique tokens each time" do
    token1 = @role.generate_preview_token!
    token2 = @role.generate_preview_token!
    assert_not_equal token1, token2
  end

  test "valid_preview_token? returns true for matching token" do
    token = @role.generate_preview_token!
    assert @role.valid_preview_token?(token)
  end

  test "valid_preview_token? returns false for non-matching token" do
    @role.generate_preview_token!
    assert_not @role.valid_preview_token?("wrong-token")
  end

  test "valid_preview_token? returns false when no token set" do
    assert_not @role.valid_preview_token?("any-token")
  end

  test "valid_preview_token? returns false for nil" do
    @role.generate_preview_token!
    assert_not @role.valid_preview_token?(nil)
  end

  test "revoke_preview_token! clears the token" do
    token = @role.generate_preview_token!
    @role.revoke_preview_token!
    assert_nil @role.reload.preview_token
    assert_not @role.valid_preview_token?(token)
  end

  test "regenerate_preview_token! replaces existing token" do
    old_token = @role.generate_preview_token!
    new_token = @role.regenerate_preview_token!
    assert_not_equal old_token, new_token
    assert @role.valid_preview_token?(new_token)
    assert_not @role.valid_preview_token?(old_token)
  end
end
