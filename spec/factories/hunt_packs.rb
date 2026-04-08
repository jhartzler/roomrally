FactoryBot.define do
  factory :hunt_pack do
    name { "Test Hunt Pack" }
    game_type { "Scavenger Hunt" }
    status { :live }

    trait :global do
      user { nil }
    end

    trait :default do
      user { nil }
      is_default { true }
    end
  end
end
