module Games
  module Broadcaster
    def self.broadcast_hand_screen(room:)
      room.players.each do |player|
        # context argument is sometimes used for logging but not strictly required for logic
        # keeping it simple for now, logging context can be added if needed or passed as optional kwarg
        Rails.logger.info({ event: "broadcast_hand_screen", player_id: player.id, room_code: room.code })

        Turbo::StreamsChannel.broadcast_update_to(
          player,
          target: "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room: room.reload, player: }
        )
      end
    end
  end
end
