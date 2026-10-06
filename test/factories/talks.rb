# test/factories/talks.rb
FactoryBot.define do
  factory :talk do
    track
    title { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    speaker_name { Faker::Name.name }
    starts_at { Faker::Time.forward(days: 30) }
    ends_at { starts_at + 45.minutes }
  end
end
