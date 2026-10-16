class RegistrationMailer < ApplicationMailer
  def confirmation(registration)
    @registration = registration
    @user         = registration.user
    @ticket_type  = registration.ticket_type
    @conference   = @ticket_type.conference

    mail(to: @user.email, subject: "You're registered for #{@conference.name}")
  end
end
