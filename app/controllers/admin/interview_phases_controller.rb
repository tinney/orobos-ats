# frozen_string_literal: true

module Admin
  # Manages interview phases within a role.
  # Accessible by admin and hiring manager users.
  # Supports create, update, delete, and reorder operations.
  class InterviewPhasesController < BaseController
    # Override inherited admin requirement — accessible to hiring managers and above
    self._required_roles = [{role: "hiring_manager"}]

    before_action :set_role
    before_action :set_interview_phase, only: %i[update destroy move]

    # POST /admin/roles/:role_id/interview_phases
    def create
      @interview_phase = @role.interview_phases.build(interview_phase_params)
      @interview_phase.company = current_company

      if @interview_phase.save
        redirect_to admin_role_path(@role), notice: "Interview phase \"#{@interview_phase.name}\" has been added."
      else
        redirect_to admin_role_path(@role), alert: @interview_phase.errors.full_messages.to_sentence
      end
    end

    # PATCH /admin/roles/:role_id/interview_phases/:id
    def update
      if @interview_phase.update(interview_phase_params)
        redirect_to admin_role_path(@role), notice: "Interview phase \"#{@interview_phase.name}\" has been updated."
      else
        redirect_to admin_role_path(@role), alert: @interview_phase.errors.full_messages.to_sentence
      end
    end

    # DELETE /admin/roles/:role_id/interview_phases/:id
    def destroy
      name = @interview_phase.name
      @interview_phase.destroy!

      # Recompact positions after deletion to maintain gap-free ordering
      InterviewPhase.recompact_positions!(@role)

      redirect_to admin_role_path(@role), notice: "Interview phase \"#{name}\" has been removed."
    end

    # PATCH /admin/roles/:role_id/interview_phases/:id/move
    def move
      new_position = params[:position].to_i
      @interview_phase.move_to(new_position)
      redirect_to admin_role_path(@role), notice: "Interview phase \"#{@interview_phase.name}\" has been moved."
    end

    private

    def set_role
      @role = Role.find(params[:role_id])
    end

    def set_interview_phase
      @interview_phase = @role.interview_phases.find(params[:id])
    end

    def interview_phase_params
      params.require(:interview_phase).permit(:name, :phase_owner_id)
    end
  end
end
