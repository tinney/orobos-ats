# frozen_string_literal: true

module Admin
  class AssignmentsController < BaseController
    # All authenticated users can access, but interviewers see only their own assignments
    self._required_roles = [{role: "interviewer"}]

    # GET /admin/assignments
    def index
      @interviews = base_scope

      # Apply filters
      @interviews = filter_by_status(@interviews)
      @interviews = filter_by_role(@interviews)
      @interviews = filter_by_interviewer(@interviews)
      @interviews = filter_by_phase(@interviews)

      # Apply sorting
      @interviews = apply_sorting(@interviews)

      # Provide filter options for the view
      @roles = Role.order(:title)
      @interviewers = users_for_filter
      @statuses = Interview::STATUSES
      @current_filters = current_filters
    end

    private

    # Interviewers see only their own assignments;
    # hiring managers and admins see all assignments across the tenant.
    def base_scope
      scope = Interview.with_full_details

      unless current_user.role_at_least?("hiring_manager")
        # Interviewers only see interviews they are assigned to
        participant_ids = InterviewParticipant.where(user_id: current_user.id).select(:interview_id)
        panel_ids = PanelInterview.where(user_id: current_user.id).select(:interview_id)
        scope = scope.where(id: participant_ids).or(scope.where(id: panel_ids))
      end

      scope
    end

    def filter_by_status(scope)
      return scope unless params[:status].present?
      return scope unless Interview::STATUSES.include?(params[:status])

      scope.where(interviews: {status: params[:status]})
    end

    def filter_by_role(scope)
      return scope unless params[:role_id].present?

      scope.joins(application: :role).where(applications: {role_id: params[:role_id]})
    end

    def filter_by_interviewer(scope)
      return scope unless params[:interviewer_id].present?
      # Only HMs and admins can filter by interviewer
      return scope unless current_user.role_at_least?("hiring_manager")

      interview_ids = InterviewParticipant.where(user_id: params[:interviewer_id]).select(:interview_id)
      scope.where(id: interview_ids)
    end

    def filter_by_phase(scope)
      return scope unless params[:phase_id].present?

      scope.where(interview_phase_id: params[:phase_id])
    end

    def apply_sorting(scope)
      case params[:sort]
      when "scheduled_at_asc"
        scope.order(Arel.sql("scheduled_at ASC NULLS LAST"))
      when "scheduled_at_desc"
        scope.order(Arel.sql("scheduled_at DESC NULLS LAST"))
      when "status"
        scope.order(Arel.sql("CASE interviews.status WHEN 'scheduled' THEN 0 WHEN 'unscheduled' THEN 1 WHEN 'complete' THEN 2 ELSE 3 END"))
      when "candidate"
        scope.joins(application: :candidate).order("candidates.last_name ASC, candidates.first_name ASC")
      when "role"
        scope.joins(application: :role).order("roles.title ASC")
      else
        # Default: prioritize upcoming scheduled, then unscheduled, then complete/cancelled
        scope.order(Arel.sql("CASE interviews.status WHEN 'scheduled' THEN 0 WHEN 'unscheduled' THEN 1 WHEN 'complete' THEN 2 ELSE 3 END, scheduled_at ASC NULLS LAST"))
      end
    end

    def users_for_filter
      return User.none unless current_user.role_at_least?("hiring_manager")

      User.active.order(:first_name, :last_name)
    end

    def current_filters
      {
        status: params[:status],
        role_id: params[:role_id],
        interviewer_id: params[:interviewer_id],
        phase_id: params[:phase_id],
        sort: params[:sort]
      }.compact_blank
    end
  end
end
