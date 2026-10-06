# test/factories/registrations.rb
FactoryBot.define do
  factory :registration do
    user
    ticket_type
    status { "confirmed" }
  end
end
