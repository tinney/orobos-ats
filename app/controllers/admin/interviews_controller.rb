# frozen_string_literal: true

module Admin
  # Manages interview events and interviewer assignments.
  # Accessible by hiring managers and above.
  class InterviewsController < BaseController
    # Override inherited admin requirement — accessible to hiring managers and above,
    # except schedule which is accessible to any authenticated user (panel membership checked separately)
    self._required_roles = [{ role: "hiring_manager", except: [:schedule] }, { role: "interviewer", only: [:schedule] }]

    before_action :set_application
    before_action :set_interview_phase
    before_action :set_interview, only: %i[remove_participant schedule complete cancel]
    before_action :require_panel_member, only: %i[schedule]

    # POST /admin/applications/:application_id/interview_phases/:interview_phase_id/interview/assign
    # Assigns an interviewer to an interview for the given application and phase.
    # Creates the interview event (unscheduled) if it doesn't already exist.
    def assign
      user = User.find(params[:user_id])

      interview = @application.interviews.find_or_initialize_by(
        interview_phase: @interview_phase
      )

      if interview.new_record?
        interview.company = current_company
        interview.save!
      end

      participant = interview.interview_participants.find_or_initialize_by(user: user)

      if participant.new_record?
        participant.save!
        redirect_back fallback_location: admin_role_path(@application.role),
                      notice: "#{user.full_name} has been assigned as interviewer."
      else
        redirect_back fallback_location: admin_role_path(@application.role),
                      alert: "#{user.full_name} is already assigned to this interview."
      end
    end

    # PATCH /admin/applications/:application_id/interview_phases/:interview_phase_id/interview/schedule
    # Allows any assigned panel member to set or update the interview time slot.
    # Hiring managers and admins can also schedule (via require_panel_member which checks both).
    def schedule
      scheduled_at = params[:scheduled_at]

      if scheduled_at.blank?
        redirect_back fallback_location: admin_role_path(@application.role),
                      alert: "Please provide a date and time for the interview."
        return
      end

      # Parse the datetime-local value in the user's timezone so it's stored as UTC.
      # The around_action sets Time.zone, and Time.zone.parse interprets the naive
      # datetime string in that zone before converting to UTC for storage.
      parsed_time = Time.zone.parse(scheduled_at)
      @interview.schedule!(parsed_time)
      redirect_back fallback_location: admin_role_path(@application.role),
                    notice: "Interview time slot has been updated."
    end

    # PATCH /admin/applications/:application_id/interview_phases/:interview_phase_id/interview/complete
    def complete
      @interview.complete!
      redirect_back fallback_location: admin_application_path(@application),
                    notice: "Interview marked as complete."
    end

    # PATCH /admin/applications/:application_id/interview_phases/:interview_phase_id/interview/cancel
    def cancel
      @interview.cancel!
      redirect_back fallback_location: admin_application_path(@application),
                    notice: "Interview cancelled."
    end

    # DELETE /admin/applications/:application_id/interview_phases/:interview_phase_id/interview/remove_participant
    def remove_participant
      participant = @interview.interview_participants.find_by!(user_id: params[:user_id])
      participant.destroy!

      redirect_back fallback_location: admin_role_path(@application.role),
                    notice: "Interviewer has been removed from this interview."
    end

    private

    def set_application
      @application = ApplicationSubmission.find(params[:application_id])
    end

    def set_interview_phase
      @interview_phase = InterviewPhase.find(params[:interview_phase_id])
    end

    def set_interview
      @interview = @application.interviews.find_by!(interview_phase: @interview_phase)
    end

    # Authorization: only panel members (assigned interviewers), hiring managers,
    # or admins can modify the time slot.
    def require_panel_member
      return if current_user.role.in?(%w[admin hiring_manager])
      return if @interview.panel_member?(current_user)

      redirect_back fallback_location: tenant_root_path,
                    alert: "Only assigned interviewers can modify this interview."
    end
  end
end
