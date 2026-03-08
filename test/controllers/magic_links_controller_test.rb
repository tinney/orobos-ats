require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
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

  # --- Login form ---

  test "GET /login renders the login form" do
    get login_url(subdomain: "testcorp")
    assert_response :success
    assert_select "form"
    assert_select "input[name='email'][type='email']"
    assert_select "input[type='submit']"
  end

  test "tenant root redirects to login" do
    get "http://testcorp.example.com/"
    assert_response :success
    assert_select "input[name='email']"
  end

  # --- Magic link request ---

  test "POST /login with valid email sends magic link and shows generic message" do
    assert_enqueued_emails 1 do
      post login_url(subdomain: "testcorp"), params: { email: "admin@testcorp.com" }
    end

    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-green-800", /we've sent you a sign-in link/i
  end

  test "POST /login with unknown email shows same generic message (no enumeration)" do
    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: { email: "unknown@example.com" }
    end

    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-green-800", /we've sent you a sign-in link/i
  end

  test "POST /login with blank email shows error" do
    post login_url(subdomain: "testcorp"), params: { email: "" }
    assert_response :unprocessable_entity
    assert_select ".text-red-800", /enter your email/i
  end

  test "POST /login does not send to deactivated users" do
    ActsAsTenant.with_tenant(@company) { @user.discard! }

    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: { email: "admin@testcorp.com" }
    end

    # Still shows generic message
    assert_redirected_to login_url(subdomain: "testcorp")
  end

  test "POST /login generates a valid magic link token on user" do
    post login_url(subdomain: "testcorp"), params: { email: "admin@testcorp.com" }

    @user.reload
    assert_not_nil @user.magic_link_token_digest
    assert_not_nil @user.magic_link_token_sent_at
  end
end
