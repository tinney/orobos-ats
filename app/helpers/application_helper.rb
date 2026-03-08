module ApplicationHelper
  # Format a datetime for display in the current user's timezone.
  # Returns nil if the time is nil.
  # Examples:
  #   format_time(interview.scheduled_at) => "Mar 15, 2026 2:30 PM EST"
  #   format_time(interview.scheduled_at, format: :short) => "Mar 15, 2:30 PM"
  #   format_time(interview.scheduled_at, format: :date_only) => "Mar 15, 2026"
  def format_time(time, format: :default)
    return nil if time.nil?

    zoned = time.in_time_zone(Time.zone)

    case format
    when :short
      zoned.strftime("%b %-d, %-I:%M %p")
    when :date_only
      zoned.strftime("%b %-d, %Y")
    when :time_only
      zoned.strftime("%-I:%M %p %Z")
    when :iso8601
      zoned.iso8601
    else
      zoned.strftime("%b %-d, %Y %-I:%M %p %Z")
    end
  end

  # Returns the abbreviated timezone name for display, e.g. "EST", "PST"
  def current_timezone_abbr
    Time.zone.now.strftime("%Z")
  end

  # Returns the full timezone name, e.g. "Eastern Time (US & Canada)"
  def current_timezone_name
    Time.zone.name
  end

  # Formats a time for use in HTML datetime-local inputs (YYYY-MM-DDTHH:MM).
  # Converts from UTC to the current user's timezone before formatting.
  def format_datetime_local(time)
    return nil if time.nil?

    time.in_time_zone(Time.zone).strftime("%Y-%m-%dT%H:%M")
  end
end
