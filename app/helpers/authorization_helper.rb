# frozen_string_literal: true

# View helpers for role-based UI rendering.
# These complement the Authorization concern's controller-level enforcement
# by providing convenient checks for conditionally displaying UI elements.
#
# The role hierarchy is: admin > hiring_manager > interviewer
# Each tier inherits all permissions of lower tiers.
module AuthorizationHelper
  # Check if the current user has at least the given role level.
  # Returns false if no user is logged in.
  #
  # Usage:
  #   <% if user_is_at_least?(:hiring_manager) %>
  #     <%= link_to "Manage Roles", admin_roles_path %>
  #   <% end %>
  def user_is_at_least?(role)
    current_user&.role_at_least?(role)
  end

  # Convenience: is the current user an admin?
  def user_is_admin?
    current_user&.admin?
  end

  # Convenience: is the current user at least a hiring manager?
  def user_is_at_least_hiring_manager?
    current_user&.at_least_hiring_manager?
  end

  # Convenience: is the current user at least an interviewer? (i.e., any authenticated user)
  def user_is_at_least_interviewer?
    current_user&.at_least_interviewer?
  end
end
