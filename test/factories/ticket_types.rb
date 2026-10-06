# test/factories/ticket_types.rb
FactoryBot.define do
  factory :ticket_type do
    conference
    name { ["General", "VIP", "Student", "Early Bird"].sample }
    price_cents { [2000, 5000, 10000, 15000].sample }
    capacity { [50, 100, 200].sample }
  end
end
