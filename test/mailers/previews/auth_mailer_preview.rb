# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/auth_mailer
class AuthMailerPreview < ActionMailer::Preview
  # Preview magic link email at http://localhost:3000/rails/mailers/auth_mailer/magic_link
  def magic_link
    company = Company.first || Company.new(name: "Demo Corp", subdomain: "democorp")
    user = company.users.first || User.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      company: company
    )

    AuthMailer.magic_link(user, "preview-token-abc123", company.subdomain || "democorp")
  end
end
