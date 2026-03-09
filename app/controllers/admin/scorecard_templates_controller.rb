# frozen_string_literal: true

module Admin
  # Manages reusable scorecard templates at the company level.
  # Templates define rating categories that pre-populate scorecards
  # when interviewers evaluate candidates.
  # Accessible by admins and hiring managers.
  class ScorecardTemplatesController < BaseController
    self._required_roles = [{role: "hiring_manager"}]

    before_action :set_template, only: %i[show edit update destroy]

    # GET /admin/scorecard_templates
    def index
      @templates = ScorecardsTemplate.includes(:scorecard_template_categories).order(name: :asc)
    end

    # GET /admin/scorecard_templates/new
    def new
      @template = ScorecardsTemplate.new
      3.times { @template.scorecard_template_categories.build }
    end

    # POST /admin/scorecard_templates
    def create
      @template = ScorecardsTemplate.new(template_params)
      @template.company = current_company
      assign_sort_orders(@template)

      if @template.save
        redirect_to admin_scorecard_templates_path, notice: "Scorecard template \"#{@template.name}\" created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/scorecard_templates/:id
    def show
      @categories = @template.scorecard_template_categories.ordered
    end

    # GET /admin/scorecard_templates/:id/edit
    def edit
    end

    # PATCH /admin/scorecard_templates/:id
    def update
      @template.assign_attributes(template_params)
      assign_sort_orders(@template)

      if @template.save
        redirect_to admin_scorecard_template_path(@template), notice: "Scorecard template updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/scorecard_templates/:id
    def destroy
      name = @template.name
      @template.destroy!
      redirect_to admin_scorecard_templates_path, notice: "Scorecard template \"#{name}\" deleted."
    end

    private

    def set_template
      @template = ScorecardsTemplate.find(params[:id])
    end

    def template_params
      params.require(:scorecards_template).permit(
        :name, :description,
        scorecard_template_categories_attributes: [:id, :name, :sort_order, :_destroy]
      )
    end

    # Auto-assign sort_order based on position in the form
    def assign_sort_orders(template)
      active_index = 0
      template.scorecard_template_categories.each do |cat|
        unless cat.marked_for_destruction?
          cat.sort_order = active_index
          active_index += 1
        end
      end
    end
  end
end
