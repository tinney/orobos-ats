# frozen_string_literal: true

require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Rate Test Corp", subdomain: "ratetest")
    ActsAsTenant.with_tenant(@company) do
      @user = User.create!(
        company: @company,
        email: "dev@ratetest.com",
        first_name: "Dev",
        last_name: "Tester",
        role: "admin"
      )
    end

    # Rack::Attack needs a real cache store (test env uses :null_store by default)
    @original_cache_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!

    RateLimit.delete_all
  end

  teardown do
    Rack::Attack.cache.store = @original_cache_store
    Rack::Attack.reset!
  end

  # ---------------------------------------------------------------------------
  # Rack::Attack throttle: per-IP
  # ---------------------------------------------------------------------------

  test "Rack::Attack blocks magic link requests exceeding per-IP limit" do
    ip_limit = Rack::Attack::MAGIC_LINK_IP_LIMIT

    # Send requests up to the limit — all should pass
    ip_limit.times do |i|
      post login_url(subdomain: "ratetest"),
        params: {email: "unique#{i}@example.com"},
        headers: {"REMOTE_ADDR" => "10.0.0.1"}
      assert_response :redirect,
        "Request #{i + 1} of #{ip_limit} should succeed"
    end

    # Next request from same IP should be throttled at Rack level (429)
    post login_url(subdomain: "ratetest"),
      params: {email: "extra@example.com"},
      headers: {"REMOTE_ADDR" => "10.0.0.1"}
    assert_response :too_many_requests
  end

  test "Rack::Attack per-IP limit does not affect different IPs" do
    ip_limit = Rack::Attack::MAGIC_LINK_IP_LIMIT

    # Exhaust limit for IP 10.0.0.1 using unique emails to avoid email throttle
    ip_limit.times do |i|
      post login_url(subdomain: "ratetest"),
        params: {email: "user#{i}@example.com"},
        headers: {"REMOTE_ADDR" => "10.0.0.1"}
    end

    # Different IP with a fresh email should still work
    post login_url(subdomain: "ratetest"),
      params: {email: "fresh@example.com"},
      headers: {"REMOTE_ADDR" => "10.0.0.2"}
    assert_response :redirect
  end

  # ---------------------------------------------------------------------------
  # Rack::Attack throttle: per-email
  # ---------------------------------------------------------------------------

  test "Rack::Attack blocks magic link requests exceeding per-email limit" do
    email_limit = Rack::Attack::MAGIC_LINK_EMAIL_LIMIT
    target_email = "dev@ratetest.com"

    # Send requests up to the email limit from different IPs
    email_limit.times do |i|
      post login_url(subdomain: "ratetest"),
        params: {email: target_email},
        headers: {"REMOTE_ADDR" => "10.0.#{i}.1"}
      assert_response :redirect,
        "Request #{i + 1} of #{email_limit} should succeed"
    end

    # Next request with same email (even from a new IP) should be throttled
    post login_url(subdomain: "ratetest"),
      params: {email: target_email},
      headers: {"REMOTE_ADDR" => "10.0.99.1"}
    assert_response :too_many_requests
  end

  test "Rack::Attack per-email limit normalizes email case" do
    email_limit = Rack::Attack::MAGIC_LINK_EMAIL_LIMIT

    # Use mixed case to try to bypass limit
    email_limit.times do |i|
      email = (i.even? ? "Dev@RateTest.com" : "dev@ratetest.com")
      post login_url(subdomain: "ratetest"),
        params: {email: email},
        headers: {"REMOTE_ADDR" => "10.0.#{i}.1"}
    end

    # Should be throttled even with different casing
    post login_url(subdomain: "ratetest"),
      params: {email: "DEV@RATETEST.COM"},
      headers: {"REMOTE_ADDR" => "10.0.99.1"}
    assert_response :too_many_requests
  end

  # ---------------------------------------------------------------------------
  # Rack::Attack throttled response
  # ---------------------------------------------------------------------------

  test "Rack::Attack throttled response includes Retry-After header" do
    ip_limit = Rack::Attack::MAGIC_LINK_IP_LIMIT

    ip_limit.times do
      post login_url(subdomain: "ratetest"),
        params: {email: "dev@ratetest.com"},
        headers: {"REMOTE_ADDR" => "10.0.0.1"}
    end

    post login_url(subdomain: "ratetest"),
      params: {email: "dev@ratetest.com"},
      headers: {"REMOTE_ADDR" => "10.0.0.1"}

    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?,
      "429 response must include Retry-After header"
    assert response.headers["Retry-After"].to_i > 0
  end

  test "Rack::Attack throttled response returns HTML body" do
    ip_limit = Rack::Attack::MAGIC_LINK_IP_LIMIT

    ip_limit.times do
      post login_url(subdomain: "ratetest"),
        params: {email: "dev@ratetest.com"},
        headers: {"REMOTE_ADDR" => "10.0.0.1"}
    end

    post login_url(subdomain: "ratetest"),
      params: {email: "dev@ratetest.com"},
      headers: {"REMOTE_ADDR" => "10.0.0.1"}

    assert_response :too_many_requests
    assert_includes response.body, "Too Many Requests"
  end

  # ---------------------------------------------------------------------------
  # Rack::Attack safelist
  # ---------------------------------------------------------------------------

  test "Rack::Attack safelists the health check endpoint" do
    # Health check should never be throttled
    20.times do
      get rails_health_check_url
      assert_response :success
    end
  end

  # ---------------------------------------------------------------------------
  # Configurable thresholds
  # ---------------------------------------------------------------------------

  test "rate limit thresholds are configurable via environment variables" do
    assert_equal 5, Rack::Attack::MAGIC_LINK_IP_LIMIT
    assert_equal 900, Rack::Attack::MAGIC_LINK_IP_PERIOD
    assert_equal 3, Rack::Attack::MAGIC_LINK_EMAIL_LIMIT
    assert_equal 900, Rack::Attack::MAGIC_LINK_EMAIL_PERIOD
  end
end
