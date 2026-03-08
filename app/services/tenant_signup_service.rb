class TenantSignupService
  Result = Struct.new(:success?, :company, :user, :errors, keyword_init: true)

  def initialize(company_name:, subdomain:, admin_email:, admin_first_name:, admin_last_name:)
    @company_name = company_name
    @subdomain = subdomain
    @admin_email = admin_email
    @admin_first_name = admin_first_name
    @admin_last_name = admin_last_name
  end

  def call
    company = nil
    user = nil

    ActiveRecord::Base.transaction do
      company = Company.create!(
        name: @company_name,
        subdomain: @subdomain
      )

      # Set tenant context for user creation with acts_as_tenant
      ActsAsTenant.with_tenant(company) do
        user = User.create!(
          company: company,
          email: @admin_email,
          first_name: @admin_first_name,
          last_name: @admin_last_name,
          role: "admin"
        )
      end
    end

    Result.new(success?: true, company: company, user: user, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    errors = e.record.errors.full_messages
    Result.new(success?: false, company: company, user: user, errors: errors)
  rescue ActiveRecord::RecordNotUnique => e
    message = if e.message.include?("subdomain")
                "Subdomain has already been taken"
    elsif e.message.include?("email")
                "Email has already been taken"
    else
                "A record with that value already exists"
    end
    Result.new(success?: false, company: nil, user: nil, errors: [ message ])
  end
end
