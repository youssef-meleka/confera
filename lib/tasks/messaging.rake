namespace :messaging do
  desc "Consume registration.created events and send confirmation emails"
  task consume_registration_emails: :environment do
    Messaging::Consumers::RegistrationEmail.new.run
  end

  desc "Consume registration.created events from Kafka and maintain the analytics rollup"
  task consume_registration_analytics: :environment do
    Messaging::Consumers::RegistrationAnalytics.new.run
  end
end
