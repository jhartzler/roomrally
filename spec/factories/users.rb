FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password" }
    provider { "google_oauth2" }
    uid { "123456" }
  end
end
