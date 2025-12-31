FactoryBot.define do
  factory :vote do
    player { association :player }
    response do
      # Ensure response belongs to a player in the same room
      association :response, player: create(:player, room: player.room)
    end
  end
end
