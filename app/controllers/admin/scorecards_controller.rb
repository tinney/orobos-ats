# frozen_string_literal: true

module Admin
  class ScorecardsController < BaseController
    self._required_roles = [{ role: "interviewer" }]

    before_action :set_interview
    before_action :set_scorecard, only: [:edit, :update]

    # GET /admin/interviews/:interview_id/scorecards/new
    def new
      @scorecard = @interview.scorecards.build(user: current_user)
      3.times { @scorecard.scorecard_categories.build }
    end

    # POST /admin/interviews/:interview_id/scorecards
    def create
      @scorecard = @interview.scorecards.build(scorecard_params)
      @scorecard.user = current_user
      @scorecard.company = current_company

      if @scorecard.save
        redirect_to admin_application_path(@interview.application), notice: "Scorecard saved."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/interviews/:interview_id/scorecards/:id/edit
    def edit
      ensure_own_scorecard!
    end

    # PATCH /admin/interviews/:interview_id/scorecards/:id
    def update
      ensure_own_scorecard!
      if @scorecard.update(scorecard_params)
        redirect_to admin_application_path(@interview.application), notice: "Scorecard updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # GET /admin/interviews/:interview_id/scorecards/:id
    def show
      @scorecard = @interview.scorecards.find(params[:id])
      # Blind feedback enforcement: interviewers can only see their own
      unless can_view_scorecard?(@scorecard)
        redirect_to admin_application_path(@interview.application), alert: "You cannot view this scorecard."
      end
    end

    private

    def set_interview
      @interview = Interview.find(params[:interview_id])
    end

    def set_scorecard
      @scorecard = @interview.scorecards.find(params[:id])
    end

    def ensure_own_scorecard!
      unless @scorecard.user_id == current_user.id
        redirect_to admin_application_path(@interview.application), alert: "You can only edit your own scorecard."
      end
    end

    def can_view_scorecard?(scorecard)
      return true if current_user.admin?
      return true if current_user.at_least_hiring_manager?
      # Phase owner can see scorecards for their phase
      phase = @interview.interview_phase
      return true if phase.phase_owner_id == current_user.id
      # Interviewers can only see their own
      scorecard.user_id == current_user.id
    end

    def scorecard_params
      params.require(:scorecard).permit(:notes, :submitted,
        scorecard_categories_attributes: [:id, :name, :rating, :_destroy])
    end
  end
end
