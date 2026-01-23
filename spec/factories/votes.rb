FactoryBot.define do
  factory :vote do
    response
    player { association :player, room: response.player.room }
  end
end
