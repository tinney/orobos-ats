# frozen_string_literal: true

module Admin
  # Manages job roles within a tenant.
  # Accessible by admin and hiring manager users.
  # Supports CRUD and status transitions for roles.
  class RolesController < BaseController
    # Override inherited admin requirement — roles are accessible to hiring managers and above
    self._required_roles = [{role: "hiring_manager"}]

    before_action :set_role, only: %i[show edit update transition generate_preview_token revoke_preview_token]

    # GET /admin/roles
    def index
      @roles = Role.order(created_at: :desc)
    end

    # GET /admin/roles/:id
    def show
      @interview_phases = @role.interview_phases.active.ordered
      @interview_phase = InterviewPhase.new
      @available_owners = User.active.where(role: %w[admin hiring_manager]).order(:first_name, :last_name)
    end

    # GET /admin/roles/new
    def new
      @role = Role.new(status: "draft")
    end

    # POST /admin/roles
    def create
      @role = Role.new(role_params)
      @role.company = current_company

      if @role.save
        redirect_to admin_roles_path, notice: "\"#{@role.title}\" has been created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/roles/:id/edit
    def edit
    end

    # PATCH/PUT /admin/roles/:id
    def update
      if @role.update(role_params)
        redirect_to admin_role_path(@role), notice: "\"#{@role.title}\" has been updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # PATCH /admin/roles/:id/transition
    # Triggers a state machine transition for the role.
    def transition
      new_status = params[:status].to_s
      @role.transition_to!(new_status, user: current_user)
      redirect_to admin_role_path(@role), notice: "\"#{@role.title}\" is now #{new_status.titleize}."
    rescue ActiveRecord::RecordInvalid
      alert_message = @role.errors[:base].first || "Cannot transition to #{new_status.titleize}."
      redirect_to admin_role_path(@role), alert: alert_message
    end

    # POST /admin/roles/:id/generate_preview_token
    def generate_preview_token
      @role.generate_preview_token!
      redirect_to admin_role_path(@role), notice: "Preview link generated."
    end

    # DELETE /admin/roles/:id/revoke_preview_token
    def revoke_preview_token
      @role.revoke_preview_token!
      redirect_to admin_role_path(@role), notice: "Preview link revoked."
    end

    private

    def set_role
      @role = Role.find(params[:id])
    end

    def role_params
      params.require(:role).permit(:title, :location, :remote, :salary_min, :salary_max, :salary_currency, :status, :description)
    end
  end
end
