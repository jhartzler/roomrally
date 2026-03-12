FactoryBot.define do
  factory :game_event do
    association :eventable, factory: :speed_trivia_game
    event_name { "state_changed" }
    metadata { { from: "waiting", to: "answering" } }
  end
end
