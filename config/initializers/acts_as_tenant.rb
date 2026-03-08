# frozen_string_literal: true

# acts_as_tenant configuration
# Ensures row-level multi-tenancy isolation on every query.
ActsAsTenant.configure do |config|
  # Raise an error when a query is made without a tenant set.
  # This prevents accidental cross-tenant data leakage.
  config.require_tenant = true
end
