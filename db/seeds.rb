# db/seeds.rb
require "factory_bot"
FactoryBot.find_definitions

puts "Seeding organizers and attendees..."
organizers = FactoryBot.create_list(:user, 5)
attendees  = FactoryBot.create_list(:user, 30)

puts "Seeding conferences, tracks, talks, ticket types, and registrations..."
organizers.each do |organizer|
  rand(2..3).times do
    conference = FactoryBot.create(:conference, organizer: organizer)

    rand(2..4).times do
      track = FactoryBot.create(:track, conference: conference)
      rand(2..5).times { FactoryBot.create(:talk, track: track) }
    end

    ticket_types = FactoryBot.create_list(:ticket_type, rand(2..3), conference: conference)

    attendees.sample(rand(5..15)).each do |attendee|
      FactoryBot.create(:registration, user: attendee, ticket_type: ticket_types.sample)
    rescue ActiveRecord::RecordInvalid
      next # skip if this (user, ticket_type) pair already exists — hits the Module 2 unique index
    end
  end
end

puts "Done:"
puts "  #{User.count} users (#{organizers.size} organizers, #{attendees.size} attendees)"
puts "  #{Conference.count} conferences"
puts "  #{Track.count} tracks"
puts "  #{Talk.count} talks"
puts "  #{TicketType.count} ticket types"
puts "  #{Registration.count} registrations"
