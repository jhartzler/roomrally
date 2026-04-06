FactoryBot.define do
  factory :poll_pack do
    name { "Poll Pack" }
    status { :live }
    user { nil }

    trait :with_questions do
      after(:create) do |pack|
        create_list(:poll_question, 3, poll_pack: pack)
      end
    end
  end
end
