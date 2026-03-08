class ApplicationMailer < ActionMailer::Base
  default from: "noreply@#{ENV.fetch('APP_DOMAIN', 'hirepilot.app')}"
  layout "mailer"
end
