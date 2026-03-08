require "test_helper"

class TenantSignupServiceTest < ActiveSupport::TestCase
  test "creates company and admin user on success" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "acme",
      admin_email: "admin@acme.com",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert result.success?
    assert_empty result.errors

    assert_equal "Acme Corp", result.company.name
    assert_equal "acme", result.company.subdomain
    assert result.company.persisted?

    assert_equal "admin@acme.com", result.user.email
    assert_equal "Jane", result.user.first_name
    assert_equal "Doe", result.user.last_name
    assert_equal "admin", result.user.role
    assert_equal result.company, result.user.company
    assert result.user.persisted?
  end

  test "fails with invalid subdomain" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "AB",
      admin_email: "admin@acme.com",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert_not result.success?
    assert result.errors.any?
    assert_equal 0, Company.count
    ActsAsTenant.without_tenant do
      assert_equal 0, User.count
    end
  end

  test "fails with reserved subdomain" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "admin",
      admin_email: "admin@acme.com",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert_not result.success?
    assert result.errors.any? { |e| e.include?("reserved") }
  end

  test "fails with duplicate subdomain" do
    TenantSignupService.new(
      company_name: "First Corp",
      subdomain: "taken",
      admin_email: "first@example.com",
      admin_first_name: "First",
      admin_last_name: "User"
    ).call

    result = TenantSignupService.new(
      company_name: "Second Corp",
      subdomain: "taken",
      admin_email: "second@example.com",
      admin_first_name: "Second",
      admin_last_name: "User"
    ).call

    assert_not result.success?
    assert result.errors.any?
  end

  test "fails with duplicate email" do
    TenantSignupService.new(
      company_name: "First Corp",
      subdomain: "first",
      admin_email: "shared@example.com",
      admin_first_name: "First",
      admin_last_name: "User"
    ).call

    result = TenantSignupService.new(
      company_name: "Second Corp",
      subdomain: "second",
      admin_email: "shared@example.com",
      admin_first_name: "Second",
      admin_last_name: "User"
    ).call

    assert_not result.success?
    assert result.errors.any?
  end

  test "fails with missing company name" do
    result = TenantSignupService.new(
      company_name: "",
      subdomain: "acme",
      admin_email: "admin@acme.com",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert_not result.success?
    assert result.errors.any?
  end

  test "fails with missing admin email" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "acme",
      admin_email: "",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert_not result.success?
    assert result.errors.any?
  end

  test "normalizes subdomain to lowercase" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "AcMe",
      admin_email: "admin@acme.com",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert result.success?
    assert_equal "acme", result.company.subdomain
  end

  test "normalizes email to lowercase" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "acme",
      admin_email: "Admin@Acme.COM",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert result.success?
    assert_equal "admin@acme.com", result.user.email
  end

  test "transaction rolls back on user creation failure" do
    result = TenantSignupService.new(
      company_name: "Acme Corp",
      subdomain: "acme",
      admin_email: "not-an-email",
      admin_first_name: "Jane",
      admin_last_name: "Doe"
    ).call

    assert_not result.success?
    assert_equal 0, Company.count
    ActsAsTenant.without_tenant do
      assert_equal 0, User.count
    end
  end
end
