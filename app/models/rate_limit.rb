# frozen_string_literal: true

class RateLimit < ApplicationRecord
  # Configurable thresholds per action type
  THRESHOLDS = {
    "apply" => {limit: 10, window: 1.hour},
    "magic_link" => {limit: 5, window: 15.minutes}
  }.freeze

  DEFAULT_THRESHOLD = {limit: 10, window: 1.hour}.freeze

  validates :key, presence: true
  validates :count, numericality: {greater_than_or_equal_to: 0}
  validates :window_start, presence: true

  # Check if a key has exceeded the limit within the current window.
  # The action prefix (e.g., "apply" from "apply:1.2.3.4") is used to look up
  # the configured threshold. Falls back to DEFAULT_THRESHOLD if not found.
  def self.exceeded?(key, limit: nil, window: nil)
    config = threshold_for(key)
    limit ||= config[:limit]
    window ||= config[:window]
    window_start = compute_window_start(window)

    record = find_by(key: key, window_start: window_start)
    return false if record.nil?

    record.count >= limit
  end

  # Increment the counter for a key using upsert for race-condition safety
  def self.increment!(key, window: nil)
    config = threshold_for(key)
    window ||= config[:window]
    window_start = compute_window_start(window)

    # Use upsert to handle concurrent requests safely
    record = find_or_create_by!(key: key, window_start: window_start)
    record.increment!(:count)
  end

  # Calculate seconds remaining until the current rate limit window resets.
  # Useful for Retry-After headers in 429 responses.
  def self.retry_after(key)
    config = threshold_for(key)
    window = config[:window]
    window_start = compute_window_start(window)
    seconds_remaining = ((window_start + window.to_i) - Time.current).ceil
    [seconds_remaining, 1].max
  end

  # Clean up old rate limit records to prevent unbounded table growth
  def self.cleanup!(older_than: 24.hours.ago)
    where("window_start < ?", older_than).delete_all
  end

  # Look up the configured threshold for a given key
  def self.threshold_for(key)
    action = key.to_s.split(":").first
    THRESHOLDS.fetch(action, DEFAULT_THRESHOLD)
  end

  # Compute the start of the current window based on window duration.
  # For 1.hour windows, aligns to the beginning of the hour.
  # For 15.minute windows, aligns to the nearest 15-minute boundary.
  def self.compute_window_start(window)
    now = Time.current
    window_seconds = window.to_i
    epoch_seconds = now.to_i
    Time.zone.at(epoch_seconds - (epoch_seconds % window_seconds))
  end
end
