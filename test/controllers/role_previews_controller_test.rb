require "test_helper"

class RolePreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.with_tenant(@company) do
      @role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft",
        location: "San Francisco, CA",
        remote: true,
        salary_min: 100_000,
        salary_max: 150_000,
        salary_currency: "USD"
      )
    end

    host! "testcorp.example.com"
  end

  # ==========================================
  # Valid preview token
  # ==========================================

  test "can view draft role with valid preview token" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role, token: token)
    assert_response :success
    assert_match "Software Engineer", response.body
    assert_match "Preview Mode", response.body
  end

  test "preview shows role details" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role, token: token)
    assert_response :success
    assert_match "San Francisco, CA", response.body
    assert_match "Remote", response.body
    assert_match "100,000", response.body
  end

  test "preview page has noindex meta tag" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role, token: token)
    assert_response :success
    assert_match "noindex", response.body
  end

  # ==========================================
  # Invalid/missing token
  # ==========================================

  test "returns 403 with invalid token" do
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role, token: "wrong-token")
    assert_response :forbidden
    assert_match "Invalid or expired preview link", response.body
  end

  test "returns 403 with no token" do
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role)
    assert_response :forbidden
  end

  test "returns 403 when no preview token has been generated" do
    get role_preview_path(@role, token: "anything")
    assert_response :forbidden
  end

  # ==========================================
  # Revoked token
  # ==========================================

  test "returns 403 after token is revoked" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }

    # Verify it works
    get role_preview_path(@role, token: token)
    assert_response :success

    # Revoke it
    ActsAsTenant.with_tenant(@company) { @role.revoke_preview_token! }

    # Verify it no longer works
    get role_preview_path(@role, token: token)
    assert_response :forbidden
  end

  # ==========================================
  # Multi-tenant isolation
  # ==========================================

  test "cannot preview role from another tenant using their subdomain" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      r = Role.create!(company: other_company, title: "Secret Role", status: "draft")
      r.generate_preview_token!
      r
    end

    # Try to access other company's role on testcorp's subdomain
    get role_preview_path(other_role, token: other_role.preview_token)
    assert_response :not_found
  end

  # ==========================================
  # Works for any role status
  # ==========================================

  test "preview works for published roles too" do
    ActsAsTenant.with_tenant(@company) do
      @role.update!(status: "published")
      @role.generate_preview_token!
    end
    get role_preview_path(@role, token: @role.reload.preview_token)
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  # ==========================================
  # No authentication required
  # ==========================================

  test "preview does not require authentication" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    # No sign_in call - just hit the preview URL
    get role_preview_path(@role, token: token)
    assert_response :success
  end
end
