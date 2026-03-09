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
      @admin = User.create!(
        company: @company,
        first_name: "Admin",
        last_name: "User",
        email: "admin-preview@example.com",
        role: "admin"
      )
      @hiring_manager = User.create!(
        company: @company,
        first_name: "HM",
        last_name: "User",
        email: "hm-preview@example.com",
        role: "hiring_manager"
      )
      @interviewer = User.create!(
        company: @company,
        first_name: "Interviewer",
        last_name: "User",
        email: "interviewer-preview@example.com",
        role: "interviewer"
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

  test "returns 403 with no token when not authenticated" do
    ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role)
    assert_response :forbidden
  end

  test "returns 403 when no preview token has been generated and not authenticated" do
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
  # Token-based: No authentication required
  # ==========================================

  test "token-based preview does not require authentication" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    # No sign_in call - just hit the preview URL
    get role_preview_path(@role, token: token)
    assert_response :success
  end

  # ==========================================
  # Authenticated preview (no token needed)
  # ==========================================

  test "authenticated admin can preview draft role without token" do
    sign_in(@admin)
    get role_preview_path(@role)
    assert_response :success
    assert_match "Software Engineer", response.body
    assert_match "Preview Mode", response.body
  end

  test "authenticated hiring manager can preview draft role without token" do
    sign_in(@hiring_manager)
    get role_preview_path(@role)
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  test "authenticated interviewer can preview draft role without token" do
    sign_in(@interviewer)
    get role_preview_path(@role)
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  test "authenticated preview shows back to role link" do
    sign_in(@admin)
    get role_preview_path(@role)
    assert_response :success
    assert_match "Back to role", response.body
  end

  test "token-based preview does not show back to role link" do
    token = ActsAsTenant.with_tenant(@company) { @role.generate_preview_token! }
    get role_preview_path(@role, token: token)
    assert_response :success
    assert_no_match "Back to role", response.body
  end

  test "authenticated preview works for any role status" do
    sign_in(@admin)

    # Draft
    get role_preview_path(@role)
    assert_response :success

    # Published
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "published") }
    get role_preview_path(@role)
    assert_response :success

    # Internal only
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "internal_only") }
    get role_preview_path(@role)
    assert_response :success

    # Closed
    ActsAsTenant.with_tenant(@company) { @role.update!(status: "closed") }
    get role_preview_path(@role)
    assert_response :success
  end

  test "authenticated user cannot preview role from another tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    other_role = ActsAsTenant.with_tenant(other_company) do
      Role.create!(company: other_company, title: "Secret Role", status: "draft")
    end

    sign_in(@admin)
    # The role belongs to other company - tenant scoping should 404
    get role_preview_path(other_role)
    assert_response :not_found
  end

  test "unauthenticated user without token gets 403" do
    # No sign_in, no token
    get role_preview_path(@role)
    assert_response :forbidden
  end

  private

  def sign_in(user)
    raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
  end
end
