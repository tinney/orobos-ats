class AuthMailer < ApplicationMailer
  def magic_link(user, token, subdomain)
    @user = user
    @token = token
    @subdomain = subdomain
    @magic_link_url = auth_callback_url(token: @token, host: "#{@subdomain}.#{default_domain}", protocol: default_protocol)
    @expiry_minutes = User::MAGIC_LINK_TOKEN_EXPIRY / 60

    mail(
      to: @user.email,
      subject: "Your sign-in link"
    )
  end

  private

  def default_domain
    Rails.configuration.x.app_domain || "localhost:3000"
  end

  def default_protocol
    Rails.env.production? ? "https" : "http"
  end

  def auth_callback_url(token:, host:, protocol:)
    "#{protocol}://#{host}/auth/callback?token=#{token}"
  end
end
