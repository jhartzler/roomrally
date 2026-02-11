FactoryBot.define do
  factory :game_template do
    name { "My Game" }
    game_type { "Write And Vote" }
    settings { { "timer_enabled" => false, "show_instructions" => true } }
    user
  end
end
