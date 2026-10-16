namespace :messaging do
  desc "Consume registration.created events and send confirmation emails"
  task consume_registration_emails: :environment do
    Messaging::Consumers::RegistrationEmail.new.run
  end
end
