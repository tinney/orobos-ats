# frozen_string_literal: true

module Admin
  class ScorecardTemplatesController < BaseController
    self._required_roles = [{role: "hiring_manager"}]

    before_action :set_role
    before_action :set_interview_phase
    before_action :set_scorecard_template, only: %i[show edit update destroy]

    # GET /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates
    def index
      @templates = @interview_phase.scorecards_templates.includes(:scorecard_template_categories).order(:name)
    end

    # GET /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates/new
    def new
      @template = @interview_phase.scorecards_templates.build
      @template.scorecard_template_categories.build(sort_order: 0)
    end

    # POST /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates
    def create
      @template = @interview_phase.scorecards_templates.build(scorecard_template_params)
      @template.company = current_company

      if @template.save
        redirect_to admin_role_interview_phase_scorecard_templates_path(@role, @interview_phase),
          notice: "Scorecard template \"#{@template.name}\" created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates/:id
    def show
      @categories = @template.scorecard_template_categories.ordered
    end

    # GET /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates/:id/edit
    def edit
    end

    # PATCH /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates/:id
    def update
      if @template.update(scorecard_template_params)
        redirect_to admin_role_interview_phase_scorecard_templates_path(@role, @interview_phase),
          notice: "Scorecard template \"#{@template.name}\" updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/roles/:role_id/interview_phases/:interview_phase_id/scorecard_templates/:id
    def destroy
      name = @template.name
      @template.destroy!
      redirect_to admin_role_interview_phase_scorecard_templates_path(@role, @interview_phase),
        notice: "Scorecard template \"#{name}\" deleted."
    end

    private

    def set_role
      @role = Role.find(params[:role_id])
    end

    def set_interview_phase
      @interview_phase = @role.interview_phases.find(params[:interview_phase_id])
    end

    def set_scorecard_template
      @template = @interview_phase.scorecards_templates.find(params[:id])
    end

    def scorecard_template_params
      params.require(:scorecards_template).permit(
        :name, :description,
        scorecard_template_categories_attributes: [
          :id, :name, :sort_order, :rating_scale, :_destroy
        ]
      )
    end
  end
end
