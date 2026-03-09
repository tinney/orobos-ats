# frozen_string_literal: true

# Public-facing controller for job listings on tenant subdomains.
# No authentication required — visitors can browse published roles.
# Displays tenant-branded careers page with published roles as a flat list.
class CareersController < ApplicationController
  # Tenant is resolved from subdomain via ApplicationController,
  # but no login is required for public careers pages.

  layout "careers"

  # GET /careers
  def index
    @roles = Role.publicly_visible.order(created_at: :desc)
  end

  # GET /careers/:id
  # Returns 404 for roles that are not published (draft, internal_only, closed).
  def show
    @role = Role.publicly_visible.find(params[:id])
  end
end
