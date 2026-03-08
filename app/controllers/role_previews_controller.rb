# frozen_string_literal: true

# Allows viewing draft/unpublished roles via a secret preview token URL.
# Accessible on tenant subdomains without authentication.
# URL format: /jobs/:id/preview?token=xyz
class RolePreviewsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: []

  def show
    @role = Role.find(params[:id])
    token = params[:token].to_s

    unless @role.valid_preview_token?(token)
      render plain: "Invalid or expired preview link", status: :forbidden
      return
    end

    @company = current_company
    render layout: "preview"
  end
end
