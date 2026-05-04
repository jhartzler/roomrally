class ResponsesController < ApplicationController
  include RendersHand

  def update
    @response = Response.find(params[:id])
    if @response.update(response_params)
      # Broadcast success message
      Rails.logger.info({ event: "response_submitted", player_id: @response.player.id, prompt_instance_id: @response.prompt_instance.id })
      @response.prompt_instance.update(status: "submitted")

      player = @response.player
      @room = player.room
      @authorized_player = player

      # Check if all responses are in to start voting
      game = @response.prompt_instance.write_and_vote_game
      if game.nil?
        Sentry.capture_message(
          "ResponsesController: game is nil after response saved",
          level: :error,
          extra: { response_id: @response.id }
        )
      end

      # Broadcast that a response was submitted (for facilitator/backstage)
      GameBroadcaster.broadcast_response_submitted(response: @response)

      Games::WriteAndVote.check_all_responses_submitted(game:) if game

      render_hand
    else
      # Handle errors
      # For now, we'll just log them. A more robust implementation
      # would broadcast an error message to the user.
      Rails.logger.error "Failed to save response: #{@response.errors.full_messages.to_sentence}"
    end
  end

  private

  def response_params
    params.require(:response).permit(:body).merge(status: "submitted")
  end
end
