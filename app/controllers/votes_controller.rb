class VotesController < ApplicationController
  def create
    @response = Response.find(params[:vote][:response_id])
    Rails.logger.debug({ current_player_name: current_player.name })

    # Prevent voting for own response
    if @response.player == current_player
      head :forbidden
      return
    end

    # Prevent multiple votes for the same prompt instance by the same player
    existing_vote = Vote.joins(:response)
                        .where(player: current_player)
                        .where(responses: { prompt_instance_id: @response.prompt_instance_id })
                        .first

    if existing_vote
      head :unprocessable_content
      return
    end

    @vote = Vote.create!(player: current_player, response: @response)

    # Process the vote in the game service (check for round completion, etc.)
    # We need to find the game associated with this response
    prompt_instance = @response.prompt_instance
    if prompt_instance.nil?
      Rails.logger.error "PromptInstance missing for response #{@response.id}"
      head :unprocessable_content
      return
    end

    game = prompt_instance.reload.write_and_vote_game
    if game.nil?
      # Fallback or retry logic if needed, but for now let's log it
      Rails.logger.error "Game is nil for response #{@response.id}"
    end
    game = Games::WriteAndVote.process_vote(game, @vote)

    respond_to do |format|
      format.turbo_stream { head :ok }
    end
  end
end
