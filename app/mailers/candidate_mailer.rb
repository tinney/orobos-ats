class CandidateMailer < ApplicationMailer
  def confirmation(application)
    @application = application
    @candidate = application.candidate
    @role = application.role
    @company = application.company

    mail(
      to: @candidate.email,
      subject: "Application received - #{@role.title} at #{@company.name}"
    )
  end
end
