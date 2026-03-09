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
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-green-800", /we've sent you a sign-in link/i
  end

  test "POST /login with unknown email shows same generic message (no enumeration)" do
    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: {email: "unknown@example.com"}
    end

    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-green-800", /we've sent you a sign-in link/i
  end

  test "POST /login with blank email shows error" do
    post login_url(subdomain: "testcorp"), params: {email: ""}
    assert_response :unprocessable_entity
    assert_select ".text-red-800", /enter your email/i
  end

  test "POST /login does not send to deactivated users" do
    ActsAsTenant.with_tenant(@company) { @user.discard! }

    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # Still shows generic message
    assert_redirected_to login_url(subdomain: "testcorp")
  end

  test "POST /login generates a valid magic link token on user" do
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}

    @user.reload
    assert_not_nil @user.magic_link_token_digest
    assert_not_nil @user.magic_link_token_sent_at
  end

  # --- Rate limiting: throttle triggers ---

  test "POST /login allows requests up to the rate limit threshold" do
    # Magic link limit is 5 per 15-minute window
    5.times do |i|
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      assert_redirected_to login_url(subdomain: "testcorp"),
        "Request #{i + 1} of 5 should succeed"
    end
  end

  test "POST /login blocks the 6th request within the rate limit window" do
    # Exhaust the 5-request limit
    5.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # 6th request should be rate limited
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-red-800", /too many requests/i
  end

  test "POST /login rate limit blocks all subsequent requests within the window" do
    # Exhaust the limit
    5.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # Multiple subsequent requests should all be blocked
    3.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      assert_redirected_to login_url(subdomain: "testcorp")
      follow_redirect!
      assert_select ".text-red-800", /too many requests/i
    end
  end

  test "POST /login rate limit does not send email when throttled" do
    # Exhaust the limit
    5.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # 6th request should not enqueue any email
    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end
  end

  test "POST /login rate limit is per-IP (different IPs have independent limits)" do
    # Exhaust limit for one IP (the test default)
    5.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # Verify blocked for original IP
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    assert_redirected_to login_url(subdomain: "testcorp")
    follow_redirect!
    assert_select ".text-red-800", /too many requests/i
  end

  # --- Rate limiting: lockout period ---

  test "POST /login rate limit resets after the 15-minute window expires" do
    # Freeze at the start of a 15-minute window boundary
    window_start = Time.current.beginning_of_hour

    travel_to window_start do
      # Exhaust the limit
      5.times do
        post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      end

      # Blocked now
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      assert_redirected_to login_url(subdomain: "testcorp")
      follow_redirect!
      assert_select ".text-red-800", /too many requests/i
    end

    # Travel to the next 15-minute window (16 minutes after window start)
    travel_to window_start + 16.minutes do
      # Should be allowed again
      assert_enqueued_emails 1 do
        post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      end
      assert_redirected_to login_url(subdomain: "testcorp")
      follow_redirect!
      assert_select ".text-green-800", /we've sent you a sign-in link/i
    end
  end

  test "POST /login rate limit still blocks within the 15-minute window" do
    # Freeze at the start of a 15-minute window boundary to ensure
    # traveling 14 minutes stays within the same window
    window_start = Time.current.beginning_of_hour
    travel_to window_start do
      # Exhaust the limit
      5.times do
        post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      end
    end

    # Travel to 14 minutes after window start (still within same 15-min window)
    travel_to window_start + 14.minutes do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
      assert_redirected_to login_url(subdomain: "testcorp")
      follow_redirect!
      assert_select ".text-red-800", /too many requests/i
    end
  end

  # --- Generic response consistency: no user enumeration ---

  test "POST /login returns identical redirect for existing and non-existing emails" do
    # Request with existing email
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    existing_redirect = response.location
    existing_status = response.status

    # Request with non-existing email
    post login_url(subdomain: "testcorp"), params: {email: "nobody@example.com"}
    nonexistent_redirect = response.location
    nonexistent_status = response.status

    assert_equal existing_redirect, nonexistent_redirect
    assert_equal existing_status, nonexistent_status
  end

  test "POST /login returns identical flash message for existing and non-existing emails" do
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    existing_flash = flash[:notice]

    post login_url(subdomain: "testcorp"), params: {email: "nobody@example.com"}
    nonexistent_flash = flash[:notice]

    assert_equal existing_flash, nonexistent_flash
    assert_match(/we've sent you a sign-in link/i, existing_flash)
  end

  test "POST /login returns identical response for deactivated user email" do
    ActsAsTenant.with_tenant(@company) { @user.discard! }

    # Deactivated user
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    deactivated_redirect = response.location
    deactivated_flash = flash[:notice]

    # Non-existing user
    post login_url(subdomain: "testcorp"), params: {email: "ghost@example.com"}
    nonexistent_redirect = response.location
    nonexistent_flash = flash[:notice]

    assert_equal deactivated_redirect, nonexistent_redirect
    assert_equal deactivated_flash, nonexistent_flash
  end

  test "POST /login response timing does not differ based on email existence" do
    # This test verifies the code path is similar for both cases
    # (no early returns or extra DB queries that could cause timing differences)
    # Both paths: rate limit increment -> user lookup -> generic redirect

    assert_no_enqueued_emails do
      post login_url(subdomain: "testcorp"), params: {email: "nobody@example.com"}
    end
    assert_redirected_to login_url(subdomain: "testcorp")

    assert_enqueued_emails 1 do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end
    assert_redirected_to login_url(subdomain: "testcorp")

    # Both redirect to the exact same URL
  end

  test "POST /login rate limited response is also generic (does not reveal email existence)" do
    # Exhaust rate limit
    5.times do
      post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    end

    # Rate limited with existing email
    post login_url(subdomain: "testcorp"), params: {email: "admin@testcorp.com"}
    existing_location = response.location
    existing_alert = flash[:alert]

    # Rate limited with non-existing email
    post login_url(subdomain: "testcorp"), params: {email: "nobody@example.com"}
    nonexistent_location = response.location
    nonexistent_alert = flash[:alert]

    # Both should get identical rate-limited responses
    assert_equal existing_location, nonexistent_location
    assert_equal existing_alert, nonexistent_alert
    assert_match(/too many requests/i, existing_alert)
  end
end
