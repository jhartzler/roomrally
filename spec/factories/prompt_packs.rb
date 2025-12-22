FactoryBot.define do
  factory :prompt_pack do
    name { "MyString" }
    game_type { "Write And Vote" }
    user
    is_default { false }
  end
end
