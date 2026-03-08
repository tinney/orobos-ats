# frozen_string_literal: true

require "test_helper"

class SubdomainTenantResolutionTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Acme Corp", subdomain: "acme")
    @other_company = Company.create!(name: "Other Inc", subdomain: "other")
  end

  # --- Tenant resolved from subdomain ---

  test "valid subdomain resolves to correct tenant" do
    host! "acme.example.com"
    get careers_path
    assert_response :success
  end

  test "different subdomain resolves to different tenant" do
    host! "other.example.com"
    get careers_path
    assert_response :success
  end

  test "unknown subdomain returns 404" do
    host! "nonexistent.example.com"
    get careers_path
    assert_response :not_found
    assert_includes response.body, "Unknown organization"
  end

  test "www subdomain is treated as root domain" do
    host! "www.example.com"
    get root_path
    assert_response :success
  end

  test "no subdomain serves root domain routes" do
    host! "example.com"
    get root_path
    assert_response :success
  end

  # --- Tenant data isolation ---

  test "tenant-scoped data is isolated between subdomains" do
    ActsAsTenant.with_tenant(@company) do
      Role.create!(company: @company, title: "Acme Engineer", status: "draft").tap do |r|
        r.update_column(:status, "published")
      end
    end

    ActsAsTenant.with_tenant(@other_company) do
      Role.create!(company: @other_company, title: "Other Designer", status: "draft").tap do |r|
        r.update_column(:status, "published")
      end
    end

    # Acme sees only its own roles
    host! "acme.example.com"
    get careers_path
    assert_response :success
    assert_includes response.body, "Acme Engineer"
    refute_includes response.body, "Other Designer"

    # Other sees only its own roles
    host! "other.example.com"
    get careers_path
    assert_response :success
    assert_includes response.body, "Other Designer"
    refute_includes response.body, "Acme Engineer"
  end

  # --- Subdomain case insensitivity ---

  test "subdomain matching is case insensitive" do
    host! "ACME.example.com"
    get careers_path
    assert_response :success
  end

  # --- current_company helper ---

  test "current_company is available as a helper method" do
    host! "acme.example.com"
    get careers_path
    assert_response :success
    # The careers page uses current_company for branding
    assert_includes response.body, "Acme Corp"
  end
end
