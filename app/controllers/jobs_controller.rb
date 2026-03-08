# frozen_string_literal: true

# Public-facing controller for shareable job role URLs.
# Resolves published roles by tenant subdomain and role slug.
# No authentication required.
class JobsController < ApplicationController
  layout "careers"

  # GET /jobs/:slug
  def show
    @role = Role.publicly_visible.find_by(slug: params[:slug])

    if @role.nil?
      render plain: "Not Found", status: :not_found
    end
  end
end
