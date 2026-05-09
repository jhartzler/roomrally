FactoryBot.define do
  factory :hunt_submission do
    hunt_prompt_instance
    player
    late { false }
    completed { false }
    favorite { false }
  end
end
