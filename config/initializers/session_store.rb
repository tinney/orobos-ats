# frozen_string_literal: true

# Configure session cookie to last 30 days.
# The session itself is also validated server-side via authenticated_at timestamp
# in ApplicationController#authenticate_from_session.
#
# The domain is set to the app's root domain (e.g., ".example.com") so that
# session cookies are shared across all tenant subdomains. This is essential
# for the magic link auth flow: the callback lands on the root domain and
# redirects to the tenant subdomain — the session cookie must be readable
# on both.
session_options = {
  key: "_ouroboros_session",
  expire_after: 30.days,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
}

# Set cross-subdomain cookie domain in production (e.g., ".example.com").
# In development, localhost doesn't support subdomain cookies natively,
# so we omit the domain to let the browser default.
if Rails.env.production?
  app_domain = ENV.fetch("APP_DOMAIN", "example.com")
  # Prepend dot for subdomain sharing: ".example.com"
  session_options[:domain] = ".#{app_domain.sub(/\A\./, "")}"
end

Rails.application.config.session_store :cookie_store, **session_options
