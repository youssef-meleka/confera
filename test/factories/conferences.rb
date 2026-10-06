# test/factories/conferences.rb
FactoryBot.define do
  factory :conference do
    association :organizer, factory: :user
    name { "#{Faker::Company.catch_phrase} Conference" }
    description { Faker::Lorem.paragraph }
    starts_at { Faker::Time.forward(days: 30) }
    ends_at { starts_at + 3.days }
    published { true }
  end
end
