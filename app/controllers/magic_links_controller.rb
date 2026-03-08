# frozen_string_literal: true

# Handles magic link login requests within a tenant subdomain.
# Presents the login form and processes magic link email delivery.
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

    RateLimit.increment!("magic_link:#{request.remote_ip}")

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

  def check_rate_limit
    if RateLimit.exceeded?("magic_link:#{request.remote_ip}", limit: 5)
      redirect_to login_path, alert: "Too many requests. Please try again later."
    end
  end
end
