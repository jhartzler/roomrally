FactoryBot.define do
  factory :trivia_pack do
    name { "Trivia Pack" }
    game_type { "Speed Trivia" }
    user
    is_default { false }

    trait :global do
      user { nil }
    end

    trait :default do
      user { nil }
      is_default { true }
      name { "Standard Trivia" }
    end
  end
end
