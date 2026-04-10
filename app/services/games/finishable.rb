# frozen_string_literal: true

module Games
  module Finishable
    def finish_game!(game:)
      if game.has_scoreable_data?
        game.with_lock do
          calculate_final_scores(game)
          game.finish_game!
        end
        GameEvent.log(game, "game_finished",
          duration_seconds: (Time.current - game.created_at).to_i,
          player_count: game.room.players.active_players.count,
          details: "ended by host")
        Analytics.track(
          distinct_id: Analytics.room_distinct_id(game.room),
          event: "game_completed",
          properties: Analytics.room_properties(game.room,
            player_count: game.room.players.active_players.count,
            duration_seconds: (Time.current - game.created_at).to_i,
            ended_early: true
          ).merge(Analytics.pack_properties(game.room))
        )
        game.room.finish!
        broadcast_all(game)
      else
        room = game.room
        Analytics.track(
          distinct_id: Analytics.room_distinct_id(room),
          event: "game_abandoned",
          properties: Analytics.room_properties(room,
            player_count: room.players.active_players.count,
            duration_seconds: (Time.current - game.created_at).to_i
          ).merge(Analytics.pack_properties(room))
        )
        game.destroy!
        room.update!(current_game: nil)
        room.reset_to_lobby!
        broadcast_all(room, lobby: true)
      end
    end
  end
end
