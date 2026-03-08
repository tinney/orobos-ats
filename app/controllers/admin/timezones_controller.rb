# frozen_string_literal: true

module Admin
  class TimezonesController < ApplicationController
    before_action :require_authentication

    # PATCH /admin/timezone
    # Accepts a JSON body with { time_zone: "America/New_York" }
    # Maps IANA timezone identifiers to Rails timezone names.
    def update
      iana_tz = params[:time_zone]
      rails_tz = map_iana_to_rails(iana_tz)

      if rails_tz && current_user.update(time_zone: rails_tz)
        head :ok
      else
        head :unprocessable_entity
      end
    end

    private

    # Maps an IANA timezone identifier (e.g. "America/New_York") to a Rails
    # ActiveSupport::TimeZone name (e.g. "Eastern Time (US & Canada)").
    # Returns nil if no mapping is found.
    def map_iana_to_rails(iana_identifier)
      return nil if iana_identifier.blank?

      # First check if it's already a valid Rails timezone name
      return iana_identifier if ActiveSupport::TimeZone::MAPPING.key?(iana_identifier)

      # Map IANA identifier to Rails timezone name
      ActiveSupport::TimeZone::MAPPING.each do |rails_name, iana_name|
        return rails_name if iana_name == iana_identifier
      end

      # Try TZInfo as fallback for aliases
      begin
        tz_info = TZInfo::Timezone.get(iana_identifier)
        ActiveSupport::TimeZone::MAPPING.each do |rails_name, iana_name|
          return rails_name if TZInfo::Timezone.get(iana_name).canonical_identifier == tz_info.canonical_identifier
        end
      rescue TZInfo::InvalidTimezoneIdentifier
        nil
      end

      nil
    end
  end
end
