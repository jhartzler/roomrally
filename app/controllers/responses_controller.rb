class ResponsesController < ApplicationController
  def update
    @response = Response.find(params[:id])
    if @response.update(response_params)
      # Broadcast success message
      @response.prompt_instance.update(status: "submitted")

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "prompt-instance-#{@response.prompt_instance.id}",
            partial: "responses/submission_success",
            locals: { response: @response }
          )
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
