class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@confera.test"
  layout "mailer"
end
