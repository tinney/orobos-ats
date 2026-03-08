# frozen_string_literal: true

module Constraints
  # Routes constraint that matches requests with a valid tenant subdomain.
  # Used in config/routes.rb to separate tenant-scoped routes from
  # root-domain (marketing / public) routes.
  class SubdomainConstraint
    IGNORED_SUBDOMAINS = %w[www].freeze

    def matches?(request)
      subdomain = extract_subdomain(request)
      subdomain.present? && !IGNORED_SUBDOMAINS.include?(subdomain)
    end

    private

    def extract_subdomain(request)
      # request.subdomain handles both single-level (app.example.com)
      # and multi-level TLDs (app.example.co.uk) when tld_length is configured.
      request.subdomain.presence&.downcase
    end
  end
end
