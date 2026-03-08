# frozen_string_literal: true

# Authorization concern for controller-level role enforcement.
#
# Provides a declarative `require_role` class method that sets the minimum
# role needed to access controller actions. The role hierarchy is:
#
#   admin > hiring_manager > interviewer
#
# An admin can do everything a hiring_manager can, and a hiring_manager
# can do everything an interviewer can.
#
# Usage:
#   class SomeController < ApplicationController
#     include Authorization
#     require_role :hiring_manager          # all actions need at least HM
#     require_role :admin, only: [:destroy]  # destroy needs admin
#   end
#
# For inline checks within an action:
#   authorize! :admin  # redirects with denied unless current user is at least admin
module Authorization
  extend ActiveSupport::Concern

  included do
    class_attribute :_required_roles, instance_writer: false, default: []
    before_action :enforce_authorization
    helper_method :current_user_role_at_least?
  end

  class_methods do
    # Declare the minimum role required for actions in this controller.
    #
    # @param role [Symbol, String] minimum role (:admin, :hiring_manager, :interviewer)
    # @param opts [Hash] standard before_action options (:only, :except)
    def require_role(role, **opts)
      role = role.to_s
      unless User::ROLE_HIERARCHY.key?(role)
        raise ArgumentError, "Unknown role: #{role}. Must be one of: #{User::ROLE_HIERARCHY.keys.join(', ')}"
      end

      # Duplicate the inherited array so we don't mutate the parent's
      self._required_roles = _required_roles.dup
      _required_roles << { role: role, **opts }
    end
  end

  private

  def enforce_authorization
    return authorization_denied unless current_user

    requirements = self.class._required_roles
    return if requirements.empty?

    action = action_name.to_sym

    # Find all requirements that apply to the current action.
    # If multiple apply, enforce the highest (most restrictive) role.
    applicable = requirements.select { |req| requirement_applies?(req, action) }
    return if applicable.empty?

    # Determine the highest required role among all applicable requirements
    required_level = applicable.map { |req| User::ROLE_HIERARCHY[req[:role]] }.max
    user_level = User::ROLE_HIERARCHY[current_user.role] || 0

    authorization_denied unless user_level >= required_level
  end

  # Inline authorization check for use within controller actions.
  # Call this when an action needs a higher role than the controller-level default,
  # or to enforce role checks within conditional logic.
  #
  # @param role [Symbol, String] minimum role required
  # @return [void] redirects with authorization_denied if the user lacks the role
  #
  # Example:
  #   def destroy
  #     authorize! :admin
  #     @record.destroy
  #   end
  def authorize!(role)
    role = role.to_s
    unless current_user&.role_at_least?(role)
      authorization_denied
    end
  end

  # View helper: check if the current user has at least the given role.
  # Use in templates to conditionally show/hide UI elements based on role.
  #
  # Example:
  #   <% if current_user_role_at_least?(:hiring_manager) %>
  #     <%= link_to "Manage Applications", admin_roles_path %>
  #   <% end %>
  def current_user_role_at_least?(role)
    current_user&.role_at_least?(role)
  end

  def requirement_applies?(req, action)
    if req[:only]
      Array(req[:only]).include?(action)
    elsif req[:except]
      !Array(req[:except]).include?(action)
    else
      true # no filter — applies to all actions
    end
  end

  def authorization_denied
    respond_to do |format|
      format.html { redirect_to tenant_root_path, alert: "You are not authorized to access this page." }
      format.json { render json: { error: "Unauthorized" }, status: :forbidden }
    end
  end
end
