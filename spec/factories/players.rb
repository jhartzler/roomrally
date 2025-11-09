FactoryBot.define do
  factory :player do
    name { "John Doe" }
    association :room
    session_id { SecureRandom.uuid }
  end
end
