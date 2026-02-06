FactoryBot.define do
  factory :category_pack do
    name { "Category Pack" }
    game_type { "Category List" }
    user
    is_default { false }

    trait :global do
      user { nil }
    end

    trait :default do
      user { nil }
      is_default { true }
      name { "Standard Categories" }
    end
  end
end
