class ResponsesController < ApplicationController
  def update
    @response = Response.find(params[:id])
    if @response.update(response_params)
      # Broadcast success message
      @response.prompt_instance.update(status: "submitted")

      # Check if all responses are in to start voting
      game = @response.prompt_instance.write_and_vote_game
    Games::WriteAndVote.check_all_responses_submitted(game)

    game.reload

      respond_to do |format|
        format.turbo_stream do
          if game.reload.voting?
            render turbo_stream: turbo_stream.update(
              "hand_screen",
              partial: "rooms/hand_screen_content",
              locals: { room: @response.player.room.reload, player: @response.player }
            )
          else
            render turbo_stream: turbo_stream.replace(
              "prompt-instance-#{@response.prompt_instance.id}",
              partial: "responses/submission_success",
              locals: { response: @response }
            )
          end
        end
        format.html { redirect_to hand_room_path(@response.player.room) }
      end
    else
      # Handle errors
      # For now, we'll just log them. A more robust implementation
      # would broadcast an error message to the user.
      Rails.logger.error "Failed to save response: #{@response.errors.full_messages.to_sentence}"
    end
  end

  private

  def response_params
    params.require(:response).permit(:body)
  end
end
