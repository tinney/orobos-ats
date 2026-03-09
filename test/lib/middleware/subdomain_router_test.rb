# frozen_string_literal: true

require "test_helper"

class Middleware::SubdomainRouterTest < ActiveSupport::TestCase
  setup do
    @downstream_app = ->(env) { [200, {"content-type" => "text/plain"}, [env.to_json]] }
    @middleware = Middleware::SubdomainRouter.new(@downstream_app)
  end

  # --- Subdomain extraction ---

  test "extracts subdomain from tenant request" do
    env = env_for("acme.example.com")
    _status, _headers, _body = @middleware.call(env)

    assert_equal "acme", env["tenant.subdomain"]
    assert_equal :tenant, env["tenant.request_type"]
  end

  test "normalizes subdomain to lowercase" do
    env = env_for("ACME.example.com")
    @middleware.call(env)

    assert_equal "acme", env["tenant.subdomain"]
    assert_equal :tenant, env["tenant.request_type"]
  end

  # --- Root domain requests ---

  test "no subdomain classified as root" do
    env = env_for("example.com")
    @middleware.call(env)

    assert_nil env["tenant.subdomain"]
    assert_equal :root, env["tenant.request_type"]
  end

  test "www subdomain classified as root" do
    env = env_for("www.example.com")
    @middleware.call(env)

    assert_equal "www", env["tenant.subdomain"]
    assert_equal :root, env["tenant.request_type"]
  end

  # --- Passthrough behavior ---

  test "always passes request through to downstream app" do
    called = false
    app = ->(_env) {
      called = true
      [200, {}, ["ok"]]
    }
    middleware = Middleware::SubdomainRouter.new(app)

    middleware.call(env_for("acme.example.com"))
    assert called, "Expected downstream app to be called"
  end

  test "returns downstream app response for tenant requests" do
    app = ->(_env) { [200, {"x-custom" => "yes"}, ["hello"]] }
    middleware = Middleware::SubdomainRouter.new(app)

    status, headers, body = middleware.call(env_for("acme.example.com"))
    assert_equal 200, status
    assert_equal "yes", headers["x-custom"]
    assert_equal ["hello"], body
  end

  test "returns downstream app response for root domain" do
    app = ->(_env) { [200, {}, ["marketing"]] }
    middleware = Middleware::SubdomainRouter.new(app)

    status, _headers, body = middleware.call(env_for("example.com"))
    assert_equal 200, status
    assert_equal ["marketing"], body
  end

  # --- Edge cases ---

  test "handles hyphenated subdomains" do
    env = env_for("my-company.example.com")
    @middleware.call(env)

    assert_equal "my-company", env["tenant.subdomain"]
    assert_equal :tenant, env["tenant.request_type"]
  end

  test "handles numeric subdomains" do
    env = env_for("tenant123.example.com")
    @middleware.call(env)

    assert_equal "tenant123", env["tenant.subdomain"]
    assert_equal :tenant, env["tenant.request_type"]
  end

  private

  # Build a minimal Rack env hash for the given host.
  def env_for(host, path: "/")
    Rack::MockRequest.env_for("http://#{host}#{path}")
  end
end
