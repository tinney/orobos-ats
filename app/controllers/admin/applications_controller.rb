# frozen_string_literal: true

module Admin
  class ApplicationsController < BaseController
    # Hiring managers and above can view and manage applications.
    # Destroy (hard delete) requires admin.
    self._required_roles = [{ role: "hiring_manager" }, { role: "admin", only: [:destroy] }]

    before_action :set_role, only: [:index]
    before_action :set_application, only: [:show, :transition, :dismiss_bot_flag, :destroy, :transfer]

    # GET /admin/roles/:role_id/applications
    def index
      @applications = @role.applications
                           .includes(:candidate, :current_interview_phase)
                           .order(created_at: :desc)

      if params[:status].present?
        @applications = @applications.by_status(params[:status])
      end

      if params[:search].present?
        search = "%#{params[:search].downcase}%"
        @applications = @applications.joins(:candidate)
          .where("LOWER(candidates.first_name) LIKE :s OR LOWER(candidates.last_name) LIKE :s OR LOWER(candidates.email) LIKE :s", s: search)
      end
    end

    # GET /admin/applications/:id
    def show
      @role = @application.role
      @candidate = @application.candidate
      @interview_phases = @role.active_interview_phases
      @interviews = @application.interviews.includes(:interview_participants, :interviewers, :scorecards)
      @offers = @application.offers.order(revision: :desc)
      @linked_applications = @application.linked_applications.includes(:role)
      @question_snapshots = @application.question_snapshots.order(:created_at)
      @available_interviewers = User.active.order(:first_name)
    end

    # PATCH /admin/applications/:id/transition
    def transition
      new_status = params[:status].to_s
      reason = params[:reason].to_s.presence

      case new_status
      when "rejected"
        @application.reject!(reason: reason)
      when "withdrawn"
        @application.withdraw!(reason: reason)
      when "accepted"
        @application.accept!
      when "on_hold"
        unless current_user.at_least_hiring_manager?
          redirect_to admin_application_path(@application), alert: "Only hiring managers can put applications on hold."
          return
        end
        @application.put_on_hold!
      when "interviewing"
        @application.start_interviewing!
      when "applied"
        @application.reopen!
      else
        redirect_to admin_application_path(@application), alert: "Invalid status transition."
        return
      end

      redirect_to admin_application_path(@application), notice: "Application status updated to #{new_status.titleize}."
    end

    # PATCH /admin/applications/:id/dismiss_bot_flag
    def dismiss_bot_flag
      @application.dismiss_bot_flag!
      redirect_to admin_application_path(@application), notice: "Bot flag dismissed."
    end

    # PATCH /admin/applications/:id/move_phase
    def move_phase
      @application = ApplicationSubmission.find(params[:id])
      phase = InterviewPhase.find(params[:phase_id])
      @application.update!(current_interview_phase_id: phase.id)

      # Notify phase owner
      if phase.phase_owner.present?
        NotificationMailer.phase_owner_alert(@application, phase).deliver_later
      end

      redirect_to admin_application_path(@application), notice: "Moved to #{phase.name}."
    end

    # POST /admin/applications/:id/transfer
    def transfer
      target_role = Role.find(params[:target_role_id])
      new_app = @application.transfer_to!(target_role)
      redirect_to admin_application_path(new_app), notice: "Application transferred to #{target_role.title}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_application_path(@application), alert: e.message
    end

    # DELETE /admin/applications/:id
    def destroy
      @application.hard_delete!
      redirect_to admin_roles_path, notice: "Application permanently deleted."
    end

    private

    def set_role
      @role = Role.find(params[:role_id])
    end

    def set_application
      @application = ApplicationSubmission.find(params[:id])
    end
  end
end
