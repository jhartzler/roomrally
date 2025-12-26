module GameBroadcaster
  def self.broadcast_hand(room:)
    room.players.each do |player|
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

    # Update Backstage Host Controls
    # We replace the entire host controls section if the game just started
    if game.status == "writing" # Or whatever initial state
      Turbo::StreamsChannel.broadcast_update_to(
        room,
        target: "backstage-host-controls",
        partial: "rooms/host_controls_game_in_progress"
      )

      # Also update moderation queue to show empty state/new game state
      # We just reload the queue container to refresh context
      Turbo::StreamsChannel.broadcast_update_to(
         room,
         target: "moderation-queue",
         html: '<p class="text-gray-400 text-center italic">No active responses to moderate.</p>'
      )
    end
  end

  def self.broadcast_player_joined(room:, player:)
    Rails.logger.info({ event: "broadcast_player_joined", room_code: room.code, player_id: player.id })

    Turbo::StreamsChannel.broadcast_append_to(
      room,
      target: "player-list",
      partial: "players/player",
      locals: { player: }
    )

    Turbo::StreamsChannel.broadcast_append_to(
      room,
      target: "stage_player_list",
      partial: "players/stage_player",
      locals: { player: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "host-controls",
      partial: "rooms/host_controls",
      locals: { room: room.reload }
    )

    # Update Backstage Host Controls (Count/Button)
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "backstage-host-controls",
      partial: "backstages/host_controls",
      locals: { room: }
    )

    Turbo::StreamsChannel.broadcast_append_to(
      room,
      target: "backstage-player-list",
      partial: "players/backstage_player",
      locals: { player: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "player-count",
      html: "#{room.players.count} connected"
    )

    Turbo::StreamsChannel.broadcast_remove_to(
       room,
       target: "no-players-placeholder"
    )
  end

  def self.broadcast_player_left(room:, player:)
    Rails.logger.info({ event: "broadcast_player_left", room_code: room.code, player_id: player.id })

    Turbo::StreamsChannel.broadcast_remove_to(
      room,
      target: ActionView::RecordIdentifier.dom_id(player)
    )

    Turbo::StreamsChannel.broadcast_remove_to(
      room,
      target: "stage_player_#{player.id}"
    )

    Turbo::StreamsChannel.broadcast_remove_to(
      room,
      target: ActionView::RecordIdentifier.dom_id(player, :backstage)
    )

    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "host-controls",
      partial: "rooms/host_controls",
      locals: { room: room.reload }
    )

    # Update Backstage Host Controls (Count/Button)
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "backstage-host-controls",
      partial: "backstages/host_controls",
      locals: { room: }
    )
  end

  def self.broadcast_host_change(room:)
    Rails.logger.info({ event: "broadcast_host_change", room_code: room.code })
    # Replace the entire player list to update host status indicators
    Turbo::StreamsChannel.broadcast_replace_to(
      room,
      target: "player-list",
      partial: "rooms/player_list",
      locals: { room: }
    )
  end

  def self.broadcast_response_rejection(response:)
    Rails.logger.info({ event: "broadcast_response_rejection", response_id: response.id, player_id: response.player.id })
    Turbo::StreamsChannel.broadcast_replace_to(
      response.player,
      target: "prompt-instance-#{response.prompt_instance.id}",
      partial: "responses/form",
      locals: { response:, prompt: response.prompt_instance }
    )
  end

  def self.broadcast_response_submitted(response:)
    Rails.logger.info({ event: "broadcast_response_submitted", response_id: response.id, player_id: response.player.id })

    # Broadcast to backstage moderation queue
    Turbo::StreamsChannel.broadcast_prepend_to(
      response.player.room,
      target: "moderation-queue",
      partial: "responses/backstage_response",
      locals: { response: }
    )
  end

  def self.game_folder_name(game_type)
    game_type.downcase.gsub(" ", "_")
  end
end
