class GameTimerJob < ApplicationJob
  queue_as :default

  def perform(game, round_number, step_number = nil)
    return unless game

    # Delegate validation and handling to the game model
    game.process_timeout(round_number, step_number)
  end
end
