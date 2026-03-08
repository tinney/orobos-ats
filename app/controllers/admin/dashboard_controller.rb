# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    self._required_roles = [{ role: "interviewer" }]

    # GET /admin/dashboard
    def index
      @stage_counts = ApplicationSubmission.group(:status).count
      @role_counts = ApplicationSubmission.joins(:role)
                       .group("roles.title", :status)
                       .count
      @roles = Role.order(:title)
      @total_active = ApplicationSubmission.active.count
    end
  end
end
