# frozen_string_literal: true

module Admin
  class CustomQuestionsController < BaseController
    self._required_roles = [{ role: "hiring_manager" }]

    before_action :set_role
    before_action :set_question, only: [:update, :destroy]

    # POST /admin/roles/:role_id/custom_questions
    def create
      @question = @role.custom_questions.build(question_params)
      @question.company = current_company

      if @question.save
        redirect_to admin_role_path(@role), notice: "Custom question added."
      else
        redirect_to admin_role_path(@role), alert: @question.errors.full_messages.join(", ")
      end
    end

    # PATCH /admin/roles/:role_id/custom_questions/:id
    def update
      if @question.update(question_params)
        redirect_to admin_role_path(@role), notice: "Custom question updated."
      else
        redirect_to admin_role_path(@role), alert: @question.errors.full_messages.join(", ")
      end
    end

    # DELETE /admin/roles/:role_id/custom_questions/:id
    def destroy
      @question.destroy!
      redirect_to admin_role_path(@role), notice: "Custom question removed."
    end

    private

    def set_role
      @role = Role.find(params[:role_id])
    end

    def set_question
      @question = @role.custom_questions.find(params[:id])
    end

    def question_params
      params.require(:custom_question).permit(:label, :field_type, :required, :position, options: [])
    end
  end
end
