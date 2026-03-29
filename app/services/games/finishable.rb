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
          distinct_id: game.room.user_id ? "user_#{game.room.user_id}" : "room_#{game.room.code}",
          event: "game_completed",
          properties: { game_type: game.room.game_type, room_code: game.room.code,
                        player_count: game.room.players.active_players.count,
                        duration_seconds: (Time.current - game.created_at).to_i,
                        ended_early: true })
        game.room.finish!
        broadcast_all(game)
      else
        room = game.room
        game.destroy!
        room.update!(current_game: nil)
        room.reset_to_lobby!
        broadcast_all(room, lobby: true)
      end
    end
  end
end
