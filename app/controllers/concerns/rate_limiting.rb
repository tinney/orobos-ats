# frozen_string_literal: true

# Rate limiting concern for controllers.
#
# Provides a declarative `rate_limit_action` class method for setting up
# per-action rate limiting with proper HTTP 429 responses, Retry-After
# headers, and user-facing error messages in both JSON and HTML contexts.
#
# Usage:
#   class SomeController < ApplicationController
#     include RateLimiting
#
#     rate_limit_action :create,
#       key: ->(controller) { "apply:#{controller.request.remote_ip}" },
#       limit: 10,
#       redirect_to: ->(controller) { controller.root_path },
#       alert: "Too many requests. Please try again later."
#   end
module RateLimiting
  extend ActiveSupport::Concern

  included do
    class_attribute :_rate_limit_configs, instance_writer: false, default: {}
  end

  class_methods do
    # Declare rate limiting for a specific action.
    #
    # @param action [Symbol] the controller action to rate limit
    # @param key [Proc] a callable that receives the controller and returns the rate limit key
    # @param limit [Integer, nil] optional limit override (defaults to configured threshold)
    # @param redirect_to [Proc, nil] optional callable returning the redirect path for HTML responses
    # @param alert [String] the user-facing error message
    def rate_limit_action(action, key:, limit: nil, redirect_to: nil, alert: "Too many requests. Please try again later.")
      # Duplicate inherited hash so we don't mutate the parent's
      self._rate_limit_configs = _rate_limit_configs.dup
      _rate_limit_configs[action.to_sym] = {
        key: key,
        limit: limit,
        redirect_to: redirect_to,
        alert: alert
      }

      before_action :"check_rate_limit_for_#{action}", only: action
      define_method(:"check_rate_limit_for_#{action}") do
        enforce_rate_limit(action.to_sym)
      end
      private :"check_rate_limit_for_#{action}"
    end
  end

  private

  def enforce_rate_limit(action)
    config = self.class._rate_limit_configs[action]
    return unless config

    key = config[:key].call(self)
    exceeded = if config[:limit]
      RateLimit.exceeded?(key, limit: config[:limit])
    else
      RateLimit.exceeded?(key)
    end

    return unless exceeded

    retry_after = RateLimit.retry_after(key)

    respond_to do |format|
      format.json do
        response.set_header("Retry-After", retry_after.to_s)
        render json: {
          error: config[:alert],
          retry_after: retry_after
        }, status: :too_many_requests
      end

      format.html do
        response.set_header("Retry-After", retry_after.to_s)

        if config[:redirect_to]
          redirect_path = config[:redirect_to].call(self)
          redirect_to redirect_path, alert: config[:alert]
        else
          flash.now[:alert] = config[:alert]
          render file: Rails.root.join("public", "429.html"),
            layout: false,
            status: :too_many_requests,
            content_type: "text/html"
        end
      end

      format.any do
        response.set_header("Retry-After", retry_after.to_s)
        render plain: config[:alert], status: :too_many_requests
      end
    end
  end
end
