# frozen_string_literal: true

# Public-facing controller for shareable job role URLs.
# Resolves published roles by tenant subdomain and role slug.
# No authentication required.
class JobsController < ApplicationController
  layout "careers"

  # GET /jobs/:slug
  # Returns 404 for roles that are not published (draft, internal_only, closed).
  def show
    @role = Role.publicly_visible.find_by!(slug: params[:slug])
  end
end
