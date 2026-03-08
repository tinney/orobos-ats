# frozen_string_literal: true

# Handles magic link token verification, session creation, and logout.
# Authentication happens before tenant context is set (tokens are globally unique),
# so this controller skips subdomain tenant resolution and uses PublicController.
class SessionsController < PublicController
  # GET /auth/callback?token=<raw_token>
  # Validates the magic link token, authenticates the user, creates a session,
  # and redirects to the user's tenant subdomain.
  def create
    raw_token = params[:token]

    if raw_token.blank?
      redirect_to root_url, alert: "Invalid or missing authentication link."
      return
    end

    user = User.find_by_magic_link_token(raw_token)

    if user.nil?
      # Generic message prevents user enumeration — covers expired, already-used, and invalid tokens
      redirect_to root_url, alert: "This login link is invalid or has expired. Please request a new one."
      return
    end

    if user.discarded?
      # Deactivated users should not be able to log in
      redirect_to root_url, alert: "This login link is invalid or has expired. Please request a new one."
      return
    end

    # Token is valid — consume it (single-use) and create session
    user.consume_magic_link_token!

    # Store user ID in session for authentication
    session[:user_id] = user.id
    session[:authenticated_at] = Time.current.to_i

    # Redirect to the user's tenant subdomain dashboard
    tenant_root = root_url(subdomain: user.company.subdomain)
    redirect_to tenant_root,
                notice: "Welcome back, #{user.first_name}!",
                allow_other_host: true
  end

  # DELETE /auth/logout or /logout
  # Clears the session and redirects to the root domain.
  def destroy
    reset_session
    redirect_to root_url(subdomain: ""), notice: "You have been signed out.", allow_other_host: true
  end
end
