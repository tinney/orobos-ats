require "test_helper"

class TenantTest < ActiveSupport::TestCase
  def valid_attributes
    {
      company_name: "Acme Corp",
      subdomain: "acme",
      admin_email: "admin@acme.com"
    }
  end

  test "valid tenant is saved successfully" do
    tenant = Tenant.new(valid_attributes)
    assert tenant.valid?, tenant.errors.full_messages.join(", ")
    assert tenant.save
  end

  # --- company_name ---

  test "company_name is required" do
    tenant = Tenant.new(valid_attributes.merge(company_name: nil))
    assert_not tenant.valid?
    assert_includes tenant.errors[:company_name], "can't be blank"
  end

  # --- admin_email ---

  test "admin_email is required" do
    tenant = Tenant.new(valid_attributes.merge(admin_email: nil))
    assert_not tenant.valid?
    assert_includes tenant.errors[:admin_email], "can't be blank"
  end

  test "admin_email must be valid format" do
    tenant = Tenant.new(valid_attributes.merge(admin_email: "not-an-email"))
    assert_not tenant.valid?
    assert_includes tenant.errors[:admin_email], "must be a valid email address"
  end

  test "admin_email uniqueness is case insensitive" do
    Tenant.create!(valid_attributes)
    tenant2 = Tenant.new(valid_attributes.merge(subdomain: "other", admin_email: "ADMIN@acme.com"))
    assert_not tenant2.valid?
    assert_includes tenant2.errors[:admin_email], "has already been taken"
  end

  # --- subdomain ---

  test "subdomain is required" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: nil))
    assert_not tenant.valid?
    assert_includes tenant.errors[:subdomain], "can't be blank"
  end

  test "subdomain must be unique" do
    Tenant.create!(valid_attributes)
    tenant2 = Tenant.new(valid_attributes.merge(admin_email: "other@example.com"))
    assert_not tenant2.valid?
    assert_includes tenant2.errors[:subdomain], "has already been taken"
  end

  test "subdomain uniqueness is case insensitive" do
    Tenant.create!(valid_attributes)
    tenant2 = Tenant.new(valid_attributes.merge(subdomain: "ACME", admin_email: "other@example.com"))
    assert_not tenant2.valid?
    assert_includes tenant2.errors[:subdomain], "has already been taken"
  end

  test "subdomain must be at least 3 characters" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "ab"))
    assert_not tenant.valid?
    assert tenant.errors[:subdomain].any? { |e| e.include?("too short") }
  end

  test "subdomain with exactly 3 characters is valid" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "abc"))
    assert tenant.valid?, tenant.errors.full_messages.join(", ")
  end

  test "subdomain must be at most 63 characters" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "a" * 64))
    assert_not tenant.valid?
    assert tenant.errors[:subdomain].any? { |e| e.include?("too long") }
  end

  test "subdomain allows lowercase alphanumeric" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "mycompany123"))
    assert tenant.valid?, tenant.errors.full_messages.join(", ")
  end

  test "subdomain allows hyphens in the middle" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "my-company"))
    assert tenant.valid?, tenant.errors.full_messages.join(", ")
  end

  test "subdomain rejects uppercase letters via normalization" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "MyCompany"))
    assert tenant.valid?, "Should be valid after normalization to lowercase"
    assert_equal "mycompany", tenant.subdomain
  end

  test "subdomain rejects leading hyphen" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "-acme"))
    assert_not tenant.valid?
  end

  test "subdomain rejects trailing hyphen" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "acme-"))
    assert_not tenant.valid?
  end

  test "subdomain rejects special characters" do
    ["acme.corp", "acme_corp", "acme@corp", "acme!corp", "ac me"].each do |bad_subdomain|
      tenant = Tenant.new(valid_attributes.merge(subdomain: bad_subdomain))
      assert_not tenant.valid?, "Expected '#{bad_subdomain}' to be invalid"
    end
  end

  # --- reserved names ---

  test "reserved subdomains are rejected" do
    %w[www admin api mail app staging production].each do |reserved|
      tenant = Tenant.new(valid_attributes.merge(subdomain: reserved))
      assert_not tenant.valid?, "Expected '#{reserved}' to be rejected as reserved"
      assert_includes tenant.errors[:subdomain], "is reserved and cannot be used"
    end
  end

  # --- normalization ---

  test "subdomain is normalized to lowercase before validation" do
    tenant = Tenant.new(valid_attributes.merge(subdomain: "  AcMe  "))
    tenant.valid?
    assert_equal "acme", tenant.subdomain
  end

  # --- slug auto-generation ---

  test "slug is auto-generated from subdomain when blank" do
    tenant = Tenant.new(valid_attributes)
    tenant.valid?
    assert_equal "acme", tenant.slug
  end
end
