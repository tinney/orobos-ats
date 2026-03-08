require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.with_tenant(@company) do
      @user = User.create!(
        company: @company,
        email: "admin@testcorp.com",
        first_name: "Jane",
        last_name: "Doe",
        role: "admin"
      )
    end
  end

  # --- Valid token verification ---

  test "GET auth/verify with valid token authenticates user and redirects" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }

    get auth_callback_path(token: raw_token)

    assert_redirected_to root_url(subdomain: "testcorp")

    # Session should contain user_id (checked before cross-host redirect)
    assert_equal @user.id, session[:user_id]
    assert session[:authenticated_at].present?
  end

  test "GET auth/verify consumes token (single-use)" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }

    get auth_callback_path(token: raw_token)
    assert_redirected_to root_url(subdomain: "testcorp")

    # Token should be consumed
    @user.reload
    assert_nil @user.magic_link_token_digest
    assert_nil @user.magic_link_token_sent_at
  end

  test "GET auth/verify with already-used token fails with generic message" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }

    # First use succeeds
    get auth_callback_path(token: raw_token)
    assert_redirected_to root_url(subdomain: "testcorp")

    # Reset session to simulate a different browser
    reset!

    # Second use fails (token consumed)
    get auth_callback_path(token: raw_token)
    assert_redirected_to root_url

    # Generic error message (no user enumeration)
    assert_equal "This login link is invalid or has expired. Please request a new one.", flash[:alert]
  end

  # --- Expired token ---

  test "GET auth/verify with expired token fails" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }

    # Simulate token sent 16 minutes ago (past 15-min expiry)
    ActsAsTenant.with_tenant(@company) do
      @user.update_column(:magic_link_token_sent_at, 16.minutes.ago)
    end

    get auth_callback_path(token: raw_token)
    assert_redirected_to root_url
    assert_equal "This login link is invalid or has expired. Please request a new one.", flash[:alert]

    # Session should not be set
    assert_nil session[:user_id]
  end

  # --- Invalid token ---

  test "GET auth/verify with invalid token fails" do
    get auth_callback_path(token: "bogus-invalid-token")
    assert_redirected_to root_url
    assert_equal "This login link is invalid or has expired. Please request a new one.", flash[:alert]
  end

  test "GET auth/verify with blank token fails" do
    get auth_callback_path
    assert_redirected_to root_url
    assert_equal "Invalid or missing authentication link.", flash[:alert]
  end

  # --- Deactivated user ---

  test "GET auth/verify with deactivated user fails" do
    raw_token = ActsAsTenant.with_tenant(@company) do
      @user.generate_magic_link_token!
    end

    ActsAsTenant.with_tenant(@company) { @user.discard! }

    get auth_callback_path(token: raw_token)
    assert_redirected_to root_url
    assert_equal "This login link is invalid or has expired. Please request a new one.", flash[:alert]
  end

  # --- Logout ---

  test "DELETE auth/logout clears session and redirects" do
    # First log in
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)
    assert_equal @user.id, session[:user_id]

    # Then log out
    delete auth_logout_path
    assert_response :redirect
    assert_nil session[:user_id]
    assert_equal "You have been signed out.", flash[:notice]
  end

  # --- Session timestamp ---

  test "session stores authentication timestamp" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }

    freeze_time do
      get auth_callback_path(token: raw_token)
      assert_equal Time.current.to_i, session[:authenticated_at]
    end
  end

  # --- Welcome message ---

  test "successful login shows welcome message with user first name" do
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }
    get auth_callback_path(token: raw_token)

    assert_equal "Welcome back, Jane!", flash[:notice]
  end

  # --- Generic error messages prevent user enumeration ---

  test "all error cases use same generic message to prevent enumeration" do
    # Invalid token
    get auth_callback_path(token: "nonexistent")
    invalid_msg = flash[:alert]

    # Expired token
    raw_token = ActsAsTenant.with_tenant(@company) { @user.generate_magic_link_token! }
    ActsAsTenant.with_tenant(@company) do
      @user.update_column(:magic_link_token_sent_at, 20.minutes.ago)
    end
    get auth_callback_path(token: raw_token)

    # Same generic message for both invalid and expired
    assert_equal invalid_msg, flash[:alert]
  end
end
