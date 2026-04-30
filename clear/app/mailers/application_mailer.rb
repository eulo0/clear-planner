class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER")
  layout "mailer"
end
