# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Resolve tenant (Company) from subdomain and set the tenant context via acts_as_tenant.
  # This scopes all ActiveRecord queries to the current company automatically.
  set_current_tenant_through_filter
  before_action :set_tenant_from_subdomain

  around_action :set_time_zone_from_user

  private

  # Set Time.zone to the current user's preferred timezone for this request.
  # All time displays will automatically use this zone.
  # Times are always stored in UTC in the database.
  def set_time_zone_from_user
    if current_user&.time_zone.present?
      Time.use_zone(current_user.time_zone) { yield }
    else
      yield
    end
  end

  # --- Tenant Resolution ---

  # Uses the subdomain extracted by Middleware::SubdomainRouter (env['tenant.subdomain'])
  # to look up the Company and set it as the current tenant via acts_as_tenant.
  def set_tenant_from_subdomain
    subdomain = request.env["tenant.subdomain"] || request.subdomain.presence&.downcase
    return if subdomain.blank? || request.env["tenant.request_type"] == :root

    company = Company.find_by(subdomain: subdomain)

    if company
      set_current_tenant(company)
    else
      render plain: "Unknown organization", status: :not_found
    end
  end

  def current_company
    ActsAsTenant.current_tenant
  end
  helper_method :current_company

  # --- Authentication ---

  # Returns the currently authenticated user, or nil if not logged in.
  # Validates that:
  #   1. Session contains a user_id
  #   2. The session hasn't exceeded the 30-day duration
  #   3. The user still exists and is active (not soft-deleted)
  #   4. The user belongs to the current tenant (if tenant is set)
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_from_session
  end
  helper_method :current_user

  def logged_in?
    current_user.present?
  end
  helper_method :logged_in?

  # Before action to enforce authentication on tenant-scoped routes.
  def require_authentication
    unless current_user
      reset_session
      redirect_to root_url(subdomain: nil), alert: "Please sign in to continue.", allow_other_host: true
    end
  end

  def authenticate_from_session
    user_id = session[:user_id]
    return nil if user_id.blank?

    # Check session expiry (30 days from authentication)
    authenticated_at = session[:authenticated_at]
    if authenticated_at.blank? || Time.at(authenticated_at) < User::SESSION_DURATION.ago
      reset_session
      return nil
    end

    # Find user without tenant scoping (session may be checked before tenant is set)
    user = ActsAsTenant.without_tenant { User.find_by(id: user_id) }
    return nil unless user&.active?

    # If tenant context is set, verify user belongs to this tenant
    if current_company && user.company_id != current_company.id
      reset_session
      return nil
    end

    user
  end
end
