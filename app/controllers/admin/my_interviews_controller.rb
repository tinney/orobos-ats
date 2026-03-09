# frozen_string_literal: true

module Admin
  class MyInterviewsController < BaseController
    self._required_roles = [{role: "interviewer"}]

    # GET /admin/my_interviews
    def index
      @interviews = Interview.for_user(current_user)
        .includes(:scorecards)

      # Group interviews by role for tabular display
      @interviews_by_role = @interviews.group_by { |i| i.application.role }

      # Precompute assignment roles for the current user per interview
      @assignment_roles = {}
      @interviews.each do |interview|
        roles = []
        roles << "Interviewer" if interview.interview_participants.any? { |ip| ip.user_id == current_user.id }
        roles << "Coordinator" if interview.panel_interviews.any? { |pi| pi.user_id == current_user.id }
        @assignment_roles[interview.id] = roles.join(", ")
      end
    end
  end
end
