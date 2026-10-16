namespace :events do
  desc "Re-publish registration.created for recent confirmed registrations with no confirmation sent (SINCE_MINUTES, default 60)"
  task replay_registrations: :environment do
    since = ENV.fetch("SINCE_MINUTES", "60").to_i.minutes.ago

    Registration.confirmed.where(confirmation_sent_at: nil).where("created_at > ?", since).find_each do |r|
      Messaging::Publisher.publish(
        "registration.created",
        { registration_id: r.id, user_id: r.user_id, ticket_type_id: r.ticket_type_id },
        request_id: "replay-#{r.id}"
      )
      puts "replayed registration #{r.id}"
    end
  end
end
