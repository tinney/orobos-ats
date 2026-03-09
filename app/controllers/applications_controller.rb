# frozen_string_literal: true

class ApplicationsController < ApplicationController
  layout "careers"
  skip_before_action :verify_authenticity_token, only: [] # keep CSRF

  before_action :set_role
  before_action :check_rate_limit, only: :create

  # GET /jobs/:slug/apply
  def show
    @custom_questions = @role.custom_questions.ordered
  end

  # POST /jobs/:slug/apply
  def create
    result = ApplicationSubmissionService.new(
      role: @role,
      company: current_company,
      params: application_params,
      resume: params.dig(:application, :resume)
    ).call

    if result.success?
      RateLimit.increment!("apply:#{request.remote_ip}")
      redirect_to job_application_success_path(slug: @role.slug), notice: "Your application has been submitted!"
    else
      @custom_questions = @role.custom_questions.ordered
      flash.now[:alert] = result.errors.join(", ")
      render :show, status: :unprocessable_entity
    end
  end

  # GET /jobs/:slug/apply/success
  # @role is already set by the set_role before_action with publicly_visible filtering.
  def success
  end

  private

  # Raises ActiveRecord::RecordNotFound (404) for roles not in published state.
  def set_role
    @role = Role.publicly_visible.find_by!(slug: params[:slug])
  end

  def application_params
    params.require(:application).permit(
      :first_name, :last_name, :email, :phone, :cover_letter, :website,
      :form_loaded_at, custom_answers: {}
    )
  end

  def check_rate_limit
    if RateLimit.exceeded?("apply:#{request.remote_ip}", limit: 10)
      render plain: "Too many requests. Please try again later.", status: :too_many_requests
    end
  end
end
