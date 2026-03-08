# frozen_string_literal: true

require "test_helper"

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Acme Corp", subdomain: "acme", primary_color: "#E11D48")
    ActsAsTenant.with_tenant(@company) do
      @published_role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft",
        location: "San Francisco, CA",
        remote: true
      )
      @published_role.update_column(:status, "published")

      @draft_role = Role.create!(
        company: @company,
        title: "Draft Role",
        status: "draft"
      )

      @closed_role = Role.create!(
        company: @company,
        title: "Closed Role",
        status: "draft"
      )
      @closed_role.update_column(:status, "closed")

      @internal_role = Role.create!(
        company: @company,
        title: "Internal Only Role",
        status: "draft"
      )
      @internal_role.update_column(:status, "internal_only")
    end

    @other_company = Company.create!(name: "Other Inc", subdomain: "other")
    ActsAsTenant.with_tenant(@other_company) do
      @other_role = Role.create!(
        company: @other_company,
        title: "Other Role",
        status: "draft"
      )
      @other_role.update_column(:status, "published")
    end

    host! "acme.example.com"
  end

  # ==========================================
  # Published role accessible by slug
  # ==========================================

  test "show displays a published role by slug" do
    get job_path(slug: @published_role.slug)
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  test "show displays role details (location, remote badge)" do
    get job_path(slug: @published_role.slug)
    assert_response :success
    assert_includes response.body, "San Francisco, CA"
    assert_includes response.body, "Remote"
  end

  test "show uses careers layout" do
    get job_path(slug: @published_role.slug)
    assert_response :success
    assert_select "footer"
  end

  # ==========================================
  # 404 for non-published roles
  # ==========================================

  test "show returns not found for draft role" do
    get job_path(slug: @draft_role.slug)
    assert_response :not_found
  end

  test "show returns not found for closed role" do
    get job_path(slug: @closed_role.slug)
    assert_response :not_found
  end

  test "show returns not found for internal_only role" do
    get job_path(slug: @internal_role.slug)
    assert_response :not_found
  end

  # ==========================================
  # 404 for non-existent slugs
  # ==========================================

  test "show returns not found for non-existent slug" do
    get job_path(slug: "non-existent-role")
    assert_response :not_found
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "show returns not found for role from another tenant" do
    get job_path(slug: @other_role.slug)
    assert_response :not_found
  end

  test "unknown subdomain returns not found" do
    host! "nonexistent.example.com"
    get job_path(slug: @published_role.slug)
    assert_response :not_found
  end

  # ==========================================
  # No authentication required
  # ==========================================

  test "job page does not require authentication" do
    get job_path(slug: @published_role.slug)
    assert_response :success
  end

  # ==========================================
  # Slug generation
  # ==========================================

  test "role generates slug from title on creation" do
    ActsAsTenant.with_tenant(@company) do
      role = Role.create!(company: @company, title: "Senior Product Manager", status: "draft")
      assert_equal "senior-product-manager", role.slug
    end
  end

  test "duplicate title generates unique slug" do
    ActsAsTenant.with_tenant(@company) do
      role1 = Role.create!(company: @company, title: "Designer", status: "draft")
      role2 = Role.create!(company: @company, title: "Designer", status: "draft")
      assert_equal "designer", role1.slug
      assert_equal "designer-2", role2.slug
    end
  end

  test "same title in different tenants can have same slug" do
    ActsAsTenant.with_tenant(@company) do
      role1 = Role.create!(company: @company, title: "Engineer", status: "draft")
      assert_equal "engineer", role1.slug
    end

    ActsAsTenant.with_tenant(@other_company) do
      role2 = Role.create!(company: @other_company, title: "Engineer", status: "draft")
      assert_equal "engineer", role2.slug
    end
  end

  # ==========================================
  # Back link to careers page
  # ==========================================

  test "show includes link back to careers page" do
    get job_path(slug: @published_role.slug)
    assert_response :success
    assert_select "a[href='#{careers_path}']"
  end
end
