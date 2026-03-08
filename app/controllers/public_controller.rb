# frozen_string_literal: true

# Base controller for routes that don't require a tenant context
# (e.g., marketing pages, signup). Skips subdomain tenant resolution.
class PublicController < ApplicationController
  skip_before_action :set_tenant_from_subdomain
end
