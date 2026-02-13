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

  def self.broadcast_stage(room:, game: nil)
    game ||= room.current_game
    return unless game

    status_suffix = game.status
    # Reviewing step 2 gets its own partial for the score podium
    if game.respond_to?(:reviewing_step) && game.status == "reviewing" && game.reviewing_step == 2
      status_suffix = "reviewing_scores"
    end

    partial_name = "games/#{game_folder_name(room.game_type)}/stage_#{status_suffix}"

    Rails.logger.info({ event: "broadcast_stage", room_code: room.code, partial: partial_name })

    locals = { room:, game: }
    if game.respond_to?(:previous_top_player_ids) && game.previous_top_player_ids.present?
      locals[:previous_top_player_ids] = game.previous_top_player_ids
    end

    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "stage_content",
      partial: partial_name,
      locals:
    )
  end

  def self.broadcast_game_start(room:)
    Rails.logger.info({ event: "broadcast_game_start", room_code: room.code })

    # 1. Update Host Controls (switches to 'in progress' or game controls)
    update_all_host_controls(room)

    # 2. Reset Backstage Moderation Queue
    # We just reload the queue container to refresh context to empty state
    Turbo::StreamsChannel.broadcast_update_to(
        room,
        target: "moderation-queue",
        html: '<p class="text-gray-400 text-center italic">No active responses to moderate.</p>'
    )
  end

  def self.clear_moderation_queue(room:)
    Rails.logger.info({ event: "clear_moderation_queue", room_code: room.code })
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "moderation-queue",
      html: '<p class="text-gray-400 text-center italic">No active responses to moderate.</p>'
    )
  end

  def self.broadcast_player_joined(room:, player:)
    Rails.logger.info({ event: "broadcast_player_joined", room_code: room.code, player_id: player.id })
    update_all_player_lists(room, player:, action: :append)
    update_all_host_controls(room)
    update_backstage_meta(room)
  end

  def self.broadcast_player_left(room:, player:)
    Rails.logger.info({ event: "broadcast_player_left", room_code: room.code, player_id: player.id })
    update_all_player_lists(room, player:, action: :remove)
    update_all_host_controls(room)
  end

  def self.broadcast_player_kicked(room:, player:)
    Rails.logger.info({ event: "broadcast_player_kicked", room_code: room.code, player_id: player.id })
    # Remove from active lists
    update_all_player_lists(room, player:, action: :remove)

    # Add to waiting room
    Turbo::StreamsChannel.broadcast_append_to(
      room,
      target: "waiting-room-list",
      partial: "players/waiting_player",
      locals: { player: }
    )

    # Update hand view to show waiting message
    Turbo::StreamsChannel.broadcast_update_to(
      player,
      target: "hand_screen",
      partial: "rooms/waiting_for_approval",
      locals: { room:, player: }
    )

    update_all_host_controls(room)
    update_backstage_meta(room)
  end

  def self.broadcast_player_approved(room:, player:)
    Rails.logger.info({ event: "broadcast_player_approved", room_code: room.code, player_id: player.id })
    # Remove from waiting room
    Turbo::StreamsChannel.broadcast_remove_to(
      room,
      target: "waiting_player_#{player.id}"
    )

    # Add to active lists
    update_all_player_lists(room, player:, action: :append)

    # Update hand view to show normal game
    broadcast_hand(room:)

    update_all_host_controls(room)
    update_backstage_meta(room)
  end

  def self.broadcast_waiting_player_updated(room:, player:)
    Rails.logger.info({ event: "broadcast_waiting_player_updated", room_code: room.code, player_id: player.id })
    # Update the waiting room card with new name in backstage
    Turbo::StreamsChannel.broadcast_replace_to(
      room,
      target: "waiting_player_#{player.id}",
      partial: "players/waiting_player",
      locals: { player: }
    )

    # Update the player's own hand view to show updated name
    Turbo::StreamsChannel.broadcast_update_to(
      player,
      target: "hand_screen",
      partial: "rooms/waiting_for_approval",
      locals: { room:, player: }
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
    update_all_host_controls(room)
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

  # Private Helpers for grouped updates

  PLAYER_LIST_TARGETS = [
    { id: "player-list", partial: "players/player" },
    { id: "stage_player_list", partial: "players/stage_player" },
    { id: "backstage-player-list", partial: "players/backstage_player" }
  ].freeze

  def self.update_all_player_lists(room, player:, action:)
    PLAYER_LIST_TARGETS.each do |target_info|
      if action == :append
        # Prepend to stage so newest players appear at the top of the cloud
        broadcast_method = target_info[:id] == "stage_player_list" ? :broadcast_prepend_to : :broadcast_append_to
        Turbo::StreamsChannel.public_send(
          broadcast_method,
          room,
          target: target_info[:id],
          partial: target_info[:partial],
          locals: { player: }
        )
      elsif action == :remove
        remove_target = nil

        case target_info[:id]
        when "player-list"
          remove_target = ActionView::RecordIdentifier.dom_id(player)
        when "stage_player_list"
          remove_target = "stage_player_#{player.id}"
        when "backstage-player-list"
          remove_target = ActionView::RecordIdentifier.dom_id(player, :backstage)
        end

        if remove_target
           Turbo::StreamsChannel.broadcast_remove_to(room, target: remove_target)
        end
      end
    end
  end

  def self.update_all_host_controls(room)
    # Hand (Host) Controls
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "host-controls",
      partial: "rooms/host_controls",
      locals: { room: room.reload, backstage: false }
    )

    # Backstage Host Controls
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "backstage-host-controls",
      partial: "rooms/host_controls",
      locals: { room:, backstage: true }
    )
  end

  def self.update_backstage_meta(room)
    Turbo::StreamsChannel.broadcast_update_to(
      room,
      target: "player-count",
      html: "#{room.players.active_players.count} connected"
    )

    Turbo::StreamsChannel.broadcast_remove_to(
      room,
      target: "no-players-placeholder"
    )
  end

  def self.broadcast_host_controls(room:)
    update_all_host_controls(room)
  end

  private_class_method :update_all_player_lists, :update_all_host_controls, :update_backstage_meta
end
