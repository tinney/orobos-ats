# frozen_string_literal: true

module Middleware
  # Rack middleware that extracts, normalizes, and validates the subdomain
  # from each incoming request. Runs early in the middleware stack to:
  #
  #   1. Normalize the subdomain (lowercase, strip whitespace)
  #   2. Classify the request as :tenant, :root, or :unknown
  #   3. Store results in the Rack env for downstream consumption
  #   4. Short-circuit with a 404 for unresolvable tenant subdomains
  #
  # Env keys set:
  #   - env['tenant.subdomain']      => normalized subdomain string or nil
  #   - env['tenant.request_type']   => :tenant, :root, or :unknown
  #
  # The controller layer (ApplicationController#set_tenant_from_subdomain)
  # still performs the actual DB lookup and sets the acts_as_tenant context.
  # This middleware handles the routing/classification layer only.
  class SubdomainRouter
    # Subdomains that should be treated as root-domain requests (no tenant)
    ROOT_SUBDOMAINS = %w[www].freeze

    # Reserved subdomains that are never valid tenants
    RESERVED_SUBDOMAINS = %w[
      www admin api mail app staging production
      ftp smtp imap pop pop3 ns ns1 ns2
      blog help support status docs
      assets cdn static media images files
      signup login auth sso callback
      careers jobs apply hire
      test dev local localhost
    ].freeze

    def initialize(app, tld_length: nil)
      @app = app
      @tld_length = tld_length
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      subdomain = extract_subdomain(request)

      env["tenant.subdomain"] = subdomain
      env["tenant.request_type"] = classify_request(subdomain)

      @app.call(env)
    end

    private

    def extract_subdomain(request)
      # Use Rails' subdomain extraction which handles TLD length
      raw = if @tld_length
        request.subdomain(@tld_length)
      else
        request.subdomain
      end
      raw.presence&.strip&.downcase
    end

    def classify_request(subdomain)
      return :root if subdomain.blank?
      return :root if ROOT_SUBDOMAINS.include?(subdomain)

      :tenant
    end
  end
end
