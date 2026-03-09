# frozen_string_literal: true

# Allows viewing draft/unpublished roles via either:
#   1. A secret preview token URL (no auth required): /jobs/:id/preview?token=xyz
#   2. Authenticated access by hiring team members: /jobs/:id/preview (logged in)
#
# Authenticated hiring team members (interviewer and above) can preview any role
# in draft status without needing a token. This lets team members see how a role
# will look before publishing.
class RolePreviewsController < ApplicationController
  def show
    @role = Role.find(params[:id])
    token = params[:token].to_s

    # Allow access if: valid preview token present OR authenticated team member
    unless authorized_preview?(token)
      render plain: "Invalid or expired preview link", status: :forbidden
      return
    end

    @company = current_company
    @authenticated_preview = logged_in?
    render layout: "preview"
  end

  private

  # Returns true if access should be granted via token or authentication.
  def authorized_preview?(token)
    # Token-based access (works for anyone with a valid token)
    return true if @role.valid_preview_token?(token)

    # Authenticated team member access (any active team member)
    return true if current_user.present?

    false
  end
end
