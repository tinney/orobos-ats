# frozen_string_literal: true

# Configure session cookie to last 30 days.
# The session itself is also validated server-side via authenticated_at timestamp
# in ApplicationController#authenticate_from_session.
Rails.application.config.session_store :cookie_store,
  key: "_ouroboros_session",
  expire_after: 30.days,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
