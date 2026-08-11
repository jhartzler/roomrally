# frozen_string_literal: true

module Games
  module Startable
    def start_from_instructions(game:)
      game.with_lock do
        previous_status = game.status
        game.start_game!
        GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
      end
      broadcast_all(game)
    end
  end
end
