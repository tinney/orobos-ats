# frozen_string_literal: true

# Rack::Attack rate limiting middleware configuration.
#
# Protects magic link request endpoints from brute-force and abuse by
# throttling requests per IP address and per email address independently.
#
# Thresholds are configurable via Rails credentials or environment variables.
# Defaults are intentionally conservative to prevent abuse while allowing
# legitimate users reasonable access.
#
# See: https://github.com/rack/rack-attack

class Rack::Attack
  # Use Rails.cache as the backing store.
  # Development: memory_store  |  Production: solid_cache
  Rack::Attack.cache.store = Rails.cache

  # ---------------------------------------------------------------------------
  # Configuration — overridable via ENV or Rails credentials
  # ---------------------------------------------------------------------------

  # Per-IP: max requests to magic link endpoint per window
  MAGIC_LINK_IP_LIMIT = (ENV.fetch("RATE_LIMIT_MAGIC_LINK_IP_LIMIT", 5)).to_i
  MAGIC_LINK_IP_PERIOD = (ENV.fetch("RATE_LIMIT_MAGIC_LINK_IP_PERIOD", 900)).to_i # 15 minutes

  # Per-email: max requests per email address per window
  MAGIC_LINK_EMAIL_LIMIT = (ENV.fetch("RATE_LIMIT_MAGIC_LINK_EMAIL_LIMIT", 3)).to_i
  MAGIC_LINK_EMAIL_PERIOD = (ENV.fetch("RATE_LIMIT_MAGIC_LINK_EMAIL_PERIOD", 900)).to_i # 15 minutes

  # Per-IP: general signup endpoint throttle
  SIGNUP_IP_LIMIT = (ENV.fetch("RATE_LIMIT_SIGNUP_IP_LIMIT", 5)).to_i
  SIGNUP_IP_PERIOD = (ENV.fetch("RATE_LIMIT_SIGNUP_IP_PERIOD", 3600)).to_i # 1 hour

  # ---------------------------------------------------------------------------
  # Throttles — magic link (POST /login)
  # ---------------------------------------------------------------------------

  # Throttle magic link requests by IP address.
  # Prevents a single IP from flooding the login endpoint.
  throttle("magic_link/ip", limit: MAGIC_LINK_IP_LIMIT, period: MAGIC_LINK_IP_PERIOD) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle magic link requests by normalized email address.
  # Prevents targeted abuse against a specific email address from any IP.
  throttle("magic_link/email", limit: MAGIC_LINK_EMAIL_LIMIT, period: MAGIC_LINK_EMAIL_PERIOD) do |req|
    if req.path == "/login" && req.post?
      # Normalize email to prevent bypass via case or whitespace
      email = req.params["email"].to_s.strip.downcase
      email if email.present?
    end
  end

  # ---------------------------------------------------------------------------
  # Throttles — signup (POST /signup)
  # ---------------------------------------------------------------------------

  # Throttle signup requests by IP address.
  throttle("signup/ip", limit: SIGNUP_IP_LIMIT, period: SIGNUP_IP_PERIOD) do |req|
    if req.path == "/signup" && req.post?
      req.ip
    end
  end

  # ---------------------------------------------------------------------------
  # Throttles — auth callback (GET /auth/callback)
  # ---------------------------------------------------------------------------

  # Throttle auth callback to prevent token brute-forcing.
  throttle("auth_callback/ip", limit: 10, period: 900) do |req|
    if req.path == "/auth/callback" && req.get?
      req.ip
    end
  end

  # ---------------------------------------------------------------------------
  # Custom response for throttled requests
  # ---------------------------------------------------------------------------

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = (match_data[:period] - (now % match_data[:period])).to_i

    headers = {
      "Content-Type" => "text/html; charset=utf-8",
      "Retry-After" => retry_after.to_s
    }

    html_body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Too Many Requests</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                 display: flex; align-items: center; justify-content: center;
                 min-height: 100vh; margin: 0; background: #f9fafb; color: #374151; }
          .container { text-align: center; max-width: 480px; padding: 2rem; }
          h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
          p { color: #6b7280; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Too Many Requests</h1>
          <p>You've made too many requests. Please wait a moment and try again.</p>
          <p><small>Retry after #{retry_after} seconds.</small></p>
        </div>
      </body>
      </html>
    HTML

    [429, headers, [html_body]]
  end

  # ---------------------------------------------------------------------------
  # Safelist — allow health check endpoint through without counting
  # ---------------------------------------------------------------------------

  safelist("allow-health-check") do |req|
    req.path == "/up"
  end
end

# ---------------------------------------------------------------------------
# Logging for blocked requests (non-production environments only)
# ---------------------------------------------------------------------------
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn(
    "[Rack::Attack] Throttled #{request.env["rack.attack.matched"]} " \
    "from #{request.ip} at #{request.path}"
  )
end
