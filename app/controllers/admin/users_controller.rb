# frozen_string_literal: true

module Admin
  # Manages team members (users) within a tenant.
  # Only accessible by admin users.
  # Supports CRUD, role changes (promote/demote), and soft-delete lifecycle (deactivate/reactivate).
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update promote demote deactivate reactivate]
    before_action :prevent_self_modification, only: %i[promote demote deactivate]
    before_action :prevent_last_admin_removal, only: %i[demote deactivate]

    # GET /admin/users
    def index
      @users = User.order(:first_name, :last_name)
      @active_users = @users.active
      @deactivated_users = @users.discarded
    end

    # GET /admin/users/new
    def new
      @user = User.new
    end

    # POST /admin/users
    def create
      @user = User.new(user_params)
      @user.company = current_company

      if @user.save
        redirect_to admin_users_path, notice: "#{@user.full_name} has been added to the team."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/users/:id/edit
    def edit
    end

    # PATCH/PUT /admin/users/:id
    def update
      if @user.update(user_update_params)
        redirect_to admin_users_path, notice: "#{@user.full_name} has been updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # PATCH /admin/users/:id/promote
    # Promotes a user one level up in the role hierarchy:
    #   interviewer → hiring_manager → admin
    def promote
      new_role = next_role_up(@user.role)

      if new_role && @user.update(role: new_role)
        redirect_to admin_users_path, notice: "#{@user.full_name} has been promoted to #{new_role.titleize}."
      else
        redirect_to admin_users_path, alert: "#{@user.full_name} cannot be promoted further."
      end
    end

    # PATCH /admin/users/:id/demote
    # Demotes a user one level down in the role hierarchy:
    #   admin → hiring_manager → interviewer
    def demote
      new_role = next_role_down(@user.role)

      if new_role && @user.update(role: new_role)
        redirect_to admin_users_path, notice: "#{@user.full_name} has been demoted to #{new_role.titleize}."
      else
        redirect_to admin_users_path, alert: "#{@user.full_name} cannot be demoted further."
      end
    end

    # PATCH /admin/users/:id/deactivate
    # Soft-deletes a user (sets discarded_at). User cannot log in after deactivation.
    def deactivate
      @user.discard!
      redirect_to admin_users_path, notice: "#{@user.full_name} has been deactivated."
    end

    # PATCH /admin/users/:id/reactivate
    # Restores a soft-deleted user.
    def reactivate
      @user.undiscard!
      redirect_to admin_users_path, notice: "#{@user.full_name} has been reactivated."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    # Prevent admins from modifying their own role or deactivating themselves
    def prevent_self_modification
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot modify your own role or deactivate yourself."
      end
    end

    # Prevent demoting or deactivating the last active admin in the tenant
    def prevent_last_admin_removal
      if @user.sole_admin?
        redirect_to admin_users_path, alert: "Cannot remove the last admin. Promote another user to admin first."
      end
    end

    def user_params
      params.require(:user).permit(:email, :first_name, :last_name, :role)
    end

    # On update, don't allow role changes through the form — use promote/demote actions
    def user_update_params
      params.require(:user).permit(:email, :first_name, :last_name)
    end

    # Role hierarchy: interviewer < hiring_manager < admin
    ROLE_HIERARCHY = %w[interviewer hiring_manager admin].freeze

    def next_role_up(current_role)
      idx = ROLE_HIERARCHY.index(current_role)
      return nil if idx.nil? || idx >= ROLE_HIERARCHY.length - 1
      ROLE_HIERARCHY[idx + 1]
    end

    def next_role_down(current_role)
      idx = ROLE_HIERARCHY.index(current_role)
      return nil if idx.nil? || idx <= 0
      ROLE_HIERARCHY[idx - 1]
    end
  end
end
