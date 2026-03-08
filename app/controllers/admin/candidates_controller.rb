# frozen_string_literal: true

module Admin
  class CandidatesController < BaseController
    # Hiring managers and above can view the global candidates list.
    self._required_roles = [{ role: "hiring_manager" }]

    # GET /admin/candidates
    def index
      @applications = ApplicationSubmission
                        .includes(:candidate, :role, :current_interview_phase)
                        .order(created_at: :desc)

      @roles = Role.order(:title)
      @statuses = ApplicationSubmission::STATUSES
    end
  end
end
