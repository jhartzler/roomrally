class GameTimerJob < ApplicationJob
  queue_as :default

  def perform(game_id, round_number)
    game = WriteAndVoteGame.find_by(id: game_id)
    return unless game
    return unless game.round == round_number
    return unless game.status == "writing"

    # If the round hasn't actually ended yet (job ran too early?), reschedule?
    # Or just enforce it. We'll enforce it.

    # Trigger timeout handling in the service
    Games::WriteAndVote.handle_timeout(game:)
  end
end
