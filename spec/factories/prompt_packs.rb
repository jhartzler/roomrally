FactoryBot.define do
  factory :prompt_pack do
    name { "MyString" }
    game_type { "MyString" }
    user
    is_default { false }
  end
end
