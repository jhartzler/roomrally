# frozen_string_literal: true

module Games
  module Broadcastable
    def broadcast_all(game_or_room, lobby: false)
      if lobby
        GameBroadcaster.broadcast_lobby(room: game_or_room)
      else
        room = game_or_room.room
        GameBroadcaster.broadcast_stage(room:, game: game_or_room)
        GameBroadcaster.broadcast_hand(room:)
        GameBroadcaster.broadcast_host_controls(room:)
      end
    end
  end
end
