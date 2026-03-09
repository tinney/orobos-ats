# frozen_string_literal: true

# Handles magic link login requests within a tenant subdomain.
# Presents the login form and processes magic link email delivery.
#
# Rate limiting is enforced at two layers:
# 1. Rack::Attack middleware — throttles by IP and by email at the Rack level
# 2. Application-level RateLimit model — provides DB-backed counting as a
#    secondary defense (e.g., if cache store is cleared)
class MagicLinksController < ApplicationController
  layout "public"

  before_action :redirect_if_logged_in, only: :new
  before_action :check_rate_limit, only: :create

  # GET /login
  def new
    # Login form — just renders the email input
  end

  # POST /login
  # Looks up the user by email within the current tenant, generates a token,
  # and sends the magic link email. Always shows a generic success message
  # to prevent user enumeration.
  def create
    email = params[:email].to_s.strip.downcase

    if email.blank?
      flash.now[:alert] = "Please enter your email address."
      render :new, status: :unprocessable_entity
      return
    end

    # Track request counts in the DB for both IP and email
    RateLimit.increment!("magic_link:#{request.remote_ip}")
    RateLimit.increment!("magic_link_email:#{email}")

    user = current_company.users.active.find_by(email: email)

    if user
      raw_token = user.generate_magic_link_token!
      AuthMailer.magic_link(user, raw_token, current_company.subdomain).deliver_later
    end

    # Always redirect with the same message to prevent user enumeration
    redirect_to login_path, notice: "If an account exists with that email, we've sent you a sign-in link. Check your inbox."
  end

  private

  def redirect_if_logged_in
    redirect_to admin_dashboard_path if current_user
  end

  # Application-level rate limit check — secondary to Rack::Attack middleware.
  # Checks both per-IP and per-email thresholds.
  def check_rate_limit
    ip_exceeded = RateLimit.exceeded?("magic_link:#{request.remote_ip}", limit: 5)

    email = params[:email].to_s.strip.downcase
    email_exceeded = email.present? && RateLimit.exceeded?("magic_link_email:#{email}", limit: 3)

    if ip_exceeded || email_exceeded
      redirect_to login_path, alert: "Too many requests. Please try again later."
    end
  end
end
