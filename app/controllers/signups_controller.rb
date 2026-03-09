class SignupsController < PublicController
  layout "public"

  def new
    # Render signup form
  end

  def create
    result = TenantSignupService.new(
      company_name: signup_params[:company_name],
      subdomain: signup_params[:subdomain],
      admin_email: signup_params[:admin_email],
      admin_first_name: signup_params[:admin_first_name],
      admin_last_name: signup_params[:admin_last_name]
    ).call

    if result.success?
      redirect_to signup_success_path(tenant_subdomain: result.company.subdomain),
        notice: "Your account has been created! Check your email to sign in."
    else
      flash.now[:alert] = result.errors.join(", ")
      @form_data = signup_params
      render :new, status: :unprocessable_entity
    end
  end

  def success
    @subdomain = params[:tenant_subdomain]
  end

  def check_subdomain
    subdomain = params[:subdomain].to_s.strip.downcase

    # Validate format
    unless subdomain.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/) && subdomain.length >= 3
      render json: {available: false, message: "Must be at least 3 characters: lowercase letters, numbers, and hyphens only"}
      return
    end

    if subdomain.length > 63
      render json: {available: false, message: "Must be 63 characters or fewer"}
      return
    end

    # Check reserved
    if Company::RESERVED_SUBDOMAINS.include?(subdomain)
      render json: {available: false, message: "This subdomain is reserved"}
      return
    end

    # Check availability
    if Company.exists?(subdomain: subdomain)
      render json: {available: false, message: "This subdomain is already taken"}
    else
      render json: {available: true, message: "#{subdomain}.ouroboros.app is available!"}
    end
  end

  private

  def signup_params
    params.expect(signup: [:company_name, :subdomain, :admin_email, :admin_first_name, :admin_last_name])
  end
end
