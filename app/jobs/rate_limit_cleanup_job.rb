# frozen_string_literal: true

class RateLimitCleanupJob < ApplicationJob
  queue_as :default

  # Remove rate limit records older than 24 hours to prevent unbounded table growth.
  # Intended to be run periodically (e.g., daily via cron or recurring Solid Queue schedule).
  def perform(older_than: 24.hours.ago)
    deleted_count = RateLimit.cleanup!(older_than: older_than)
    Rails.logger.info("[RateLimitCleanupJob] Cleaned up #{deleted_count} expired rate limit records")
  end
end
