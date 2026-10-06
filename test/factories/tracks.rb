# test/factories/tracks.rb
FactoryBot.define do
  factory :track do
    conference
    name { ["Backend", "Frontend", "DevOps", "Data Science", "Security"].sample }
    description { Faker::Lorem.sentence }
  end
end
