# frozen_string_literal: true

module Admin
  # Base controller for all admin-namespaced routes.
  # Enforces authentication and admin role authorization.
  class BaseController < ApplicationController
    before_action :require_authentication

    include Authorization
    require_role :admin

    layout "admin"
  end
end
