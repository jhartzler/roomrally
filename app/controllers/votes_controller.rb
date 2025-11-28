class VotesController < ApplicationController
  def create
    @response = Response.find(params[:vote][:response_id])
    Rails.logger.info({ event: "vote_attempt", player_id: current_player.id, response_id: @response.id })

    @vote = Vote.new(player: current_player, response: @response)

    unless @vote.save
      if @vote.errors[:base].include?("You cannot vote for your own response")
        head :forbidden
      elsif @vote.errors[:base].include?("You have already voted for this prompt")
        head :unprocessable_content
      else
        head :unprocessable_content
      end
      return
    end

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
