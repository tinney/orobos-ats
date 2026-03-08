# frozen_string_literal: true

require "test_helper"

class RateLimitTest < ActiveSupport::TestCase
  setup do
    RateLimit.delete_all
  end

  # ==========================================
  # Validations
  # ==========================================

  test "requires key" do
    rl = RateLimit.new(window_start: Time.current, count: 0)
    assert_not rl.valid?
    assert_includes rl.errors[:key], "can't be blank"
  end

  test "requires window_start" do
    rl = RateLimit.new(key: "test:key", count: 0)
    assert_not rl.valid?
    assert_includes rl.errors[:window_start], "can't be blank"
  end

  test "count must be non-negative" do
    rl = RateLimit.new(key: "test:key", window_start: Time.current, count: -1)
    assert_not rl.valid?
    assert_includes rl.errors[:count], "must be greater than or equal to 0"
  end

  test "valid rate limit record" do
    rl = RateLimit.new(key: "test:key", window_start: Time.current, count: 0)
    assert rl.valid?
  end

  # ==========================================
  # Configurable thresholds
  # ==========================================

  test "threshold_for returns configured limit for apply action" do
    config = RateLimit.threshold_for("apply:1.2.3.4")
    assert_equal 10, config[:limit]
  end

  test "threshold_for returns configured limit for magic_link action" do
    config = RateLimit.threshold_for("magic_link:1.2.3.4")
    assert_equal 5, config[:limit]
  end

  test "threshold_for returns default limit for unknown action" do
    config = RateLimit.threshold_for("unknown:1.2.3.4")
    assert_equal RateLimit::DEFAULT_THRESHOLD[:limit], config[:limit]
  end

  # ==========================================
  # exceeded?
  # ==========================================

  test "exceeded? returns false when no record exists" do
    assert_not RateLimit.exceeded?("apply:1.2.3.4")
  end

  test "exceeded? returns false when count is below limit" do
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour,
      count: 5
    )
    assert_not RateLimit.exceeded?("apply:1.2.3.4")
  end

  test "exceeded? returns true when count equals configured limit" do
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour,
      count: 10
    )
    assert RateLimit.exceeded?("apply:1.2.3.4")
  end

  test "exceeded? returns true when count exceeds configured limit" do
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour,
      count: 15
    )
    assert RateLimit.exceeded?("apply:1.2.3.4")
  end

  test "exceeded? allows explicit limit override" do
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour,
      count: 3
    )
    # Default apply limit is 10, but override with 3
    assert RateLimit.exceeded?("apply:1.2.3.4", limit: 3)
  end

  test "exceeded? ignores records from previous windows" do
    # Old window record with high count
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: 2.hours.ago.beginning_of_hour,
      count: 100
    )
    # Current window doesn't exist yet
    assert_not RateLimit.exceeded?("apply:1.2.3.4")
  end

  # ==========================================
  # increment!
  # ==========================================

  test "increment! creates a new record if none exists" do
    assert_difference -> { RateLimit.count }, 1 do
      RateLimit.increment!("apply:1.2.3.4")
    end

    record = RateLimit.find_by(key: "apply:1.2.3.4")
    assert_equal 1, record.count
    assert_equal Time.current.beginning_of_hour, record.window_start
  end

  test "increment! increments existing record count" do
    RateLimit.create!(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour,
      count: 5
    )

    assert_no_difference -> { RateLimit.count } do
      RateLimit.increment!("apply:1.2.3.4")
    end

    record = RateLimit.find_by(
      key: "apply:1.2.3.4",
      window_start: Time.current.beginning_of_hour
    )
    assert_equal 6, record.count
  end

  test "increment! creates separate records for different IPs" do
    RateLimit.increment!("apply:1.1.1.1")
    RateLimit.increment!("apply:2.2.2.2")

    assert_equal 1, RateLimit.find_by(key: "apply:1.1.1.1").count
    assert_equal 1, RateLimit.find_by(key: "apply:2.2.2.2").count
  end

  # ==========================================
  # cleanup!
  # ==========================================

  test "cleanup! removes records older than threshold" do
    old_record = RateLimit.create!(
      key: "apply:old",
      window_start: 48.hours.ago,
      count: 5
    )
    recent_record = RateLimit.create!(
      key: "apply:recent",
      window_start: Time.current.beginning_of_hour,
      count: 3
    )

    RateLimit.cleanup!

    assert_nil RateLimit.find_by(id: old_record.id)
    assert_not_nil RateLimit.find_by(id: recent_record.id)
  end

  test "cleanup! accepts custom older_than parameter" do
    record = RateLimit.create!(
      key: "apply:test",
      window_start: 2.hours.ago,
      count: 5
    )

    RateLimit.cleanup!(older_than: 1.hour.ago)

    assert_nil RateLimit.find_by(id: record.id)
  end

  # ==========================================
  # Integration: IP-based rate limiting for form submissions
  # ==========================================

  test "simulates IP rate limiting for application submissions" do
    ip = "192.168.1.100"
    key = "apply:#{ip}"

    # Simulate 10 submissions (the configured limit)
    10.times { RateLimit.increment!(key) }

    # 11th should be blocked
    assert RateLimit.exceeded?(key)
  end

  test "different IPs have independent rate limits" do
    10.times { RateLimit.increment!("apply:1.1.1.1") }

    assert RateLimit.exceeded?("apply:1.1.1.1")
    assert_not RateLimit.exceeded?("apply:2.2.2.2")
  end
end
