FactoryBot.define do
  factory :scavenger_hunt_game do
    status { "instructions" }
    timer_duration { 1800 }
    timer_enabled { true }
  end
end
