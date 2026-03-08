class NotificationMailer < ApplicationMailer
  def phase_owner_alert(application, interview_phase)
    @application = application
    @candidate = application.candidate
    @role = application.role
    @company = application.company
    @phase = interview_phase
    @phase_owner = interview_phase.phase_owner

    return unless @phase_owner.present?

    mail(
      to: @phase_owner.email,
      subject: "New candidate in #{@phase.name} - #{@candidate.full_name}"
    )
  end
end
