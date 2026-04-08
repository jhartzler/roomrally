FactoryBot.define do
  factory :hunt_prompt_instance do
    scavenger_hunt_game
    hunt_prompt
    sequence(:position) { |n| n }
  end
end
