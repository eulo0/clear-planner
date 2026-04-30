class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER") || "from@example.com"
  layout "mailer"
end
