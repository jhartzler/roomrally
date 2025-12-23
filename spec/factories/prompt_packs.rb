FactoryBot.define do
  factory :prompt_pack do
    name { "MyString" }
    game_type { "Write And Vote" }
    user
    is_default { false }
    trait :global do
      user { nil }
    end

    trait :default do
      user { nil }
      is_default { true }
      name { "Standard Deck" }
    end
  end
end
