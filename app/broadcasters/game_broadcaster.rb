module GameBroadcaster
  def self.broadcast_hand(room:)
    room.players.each do |player|
      # context argument is sometimes used for logging but not strictly required for logic
      # keeping it simple for now, logging context can be added if needed or passed as optional kwarg
      Rails.logger.info({ event: "broadcast_hand", player_id: player.id, room_code: room.code })

      Turbo::StreamsChannel.broadcast_update_to(
        player,
        target: "hand_screen",
        partial: "rooms/hand_screen_content",
        locals: { room: room.reload, player: }
      )
    end
  end

  def self.broadcast_stage(room:)
    game = room.current_game
    return unless game

    # Convention: games/[game_type]/stage_[status]
    # e.g. games/write_and_vote/stage_writing
    partial_name = "games/#{game_folder_name(room.game_type)}/stage_#{game.status}"

    Rails.logger.info({ event: "broadcast_stage", room_code: room.code, partial: partial_name })

    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "stage_content",
      partial: partial_name,
      locals: { room:, game: }
    )
  end

  def self.game_folder_name(game_type)
    game_type.downcase.gsub(" ", "_")
  end
end
