# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # format_time converts UTC times to the current Time.zone for display

  test "format_time returns nil for nil input" do
    assert_nil format_time(nil)
  end

  test "format_time default format includes timezone abbreviation" do
    Time.use_zone("Eastern Time (US & Canada)") do
      # January 15, 2026 at 18:30 UTC = 1:30 PM EST
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_time(utc_time)

      assert_includes result, "1:30 PM"
      assert_includes result, "EST"
      assert_includes result, "Jan 15, 2026"
    end
  end

  test "format_time converts UTC to user timezone" do
    Time.use_zone("Pacific Time (US & Canada)") do
      # March 10, 2026 at 20:00 UTC = 1:00 PM PDT (after DST switch)
      utc_time = Time.utc(2026, 3, 10, 20, 0, 0)
      result = format_time(utc_time)

      assert_includes result, "1:00 PM"
      assert_includes result, "PDT"
    end
  end

  test "format_time short format omits year and timezone" do
    Time.use_zone("Eastern Time (US & Canada)") do
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_time(utc_time, format: :short)

      assert_includes result, "Jan 15"
      assert_includes result, "1:30 PM"
      refute_includes result, "2026"
      refute_includes result, "EST"
    end
  end

  test "format_time date_only format shows only date" do
    Time.use_zone("Eastern Time (US & Canada)") do
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_time(utc_time, format: :date_only)

      assert_includes result, "Jan 15, 2026"
      refute_includes result, "PM"
    end
  end

  test "format_time time_only format shows only time with zone" do
    Time.use_zone("Eastern Time (US & Canada)") do
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_time(utc_time, format: :time_only)

      assert_includes result, "1:30 PM EST"
    end
  end

  # format_datetime_local for HTML datetime-local inputs

  test "format_datetime_local returns nil for nil input" do
    assert_nil format_datetime_local(nil)
  end

  test "format_datetime_local converts UTC to user timezone for input value" do
    Time.use_zone("Eastern Time (US & Canada)") do
      # 18:30 UTC = 13:30 EST
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_datetime_local(utc_time)

      assert_equal "2026-01-15T13:30", result
    end
  end

  test "format_datetime_local uses Pacific timezone correctly" do
    Time.use_zone("Pacific Time (US & Canada)") do
      # 18:30 UTC = 10:30 PST
      utc_time = Time.utc(2026, 1, 15, 18, 30, 0)
      result = format_datetime_local(utc_time)

      assert_equal "2026-01-15T10:30", result
    end
  end

  test "format_datetime_local handles date rollover from timezone offset" do
    Time.use_zone("Pacific Time (US & Canada)") do
      # Jan 16 at 02:00 UTC = Jan 15 at 18:00 PST (previous day)
      utc_time = Time.utc(2026, 1, 16, 2, 0, 0)
      result = format_datetime_local(utc_time)

      assert_equal "2026-01-15T18:00", result
    end
  end

  # current_timezone_abbr and current_timezone_name

  test "current_timezone_abbr returns abbreviated zone name" do
    Time.use_zone("Eastern Time (US & Canada)") do
      # In January, EST
      travel_to Time.utc(2026, 1, 15) do
        assert_equal "EST", current_timezone_abbr
      end
    end
  end

  test "current_timezone_name returns full zone name" do
    Time.use_zone("Eastern Time (US & Canada)") do
      assert_equal "Eastern Time (US & Canada)", current_timezone_name
    end
  end
end
