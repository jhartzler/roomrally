class ResponsesController < ApplicationController
  def update
    @response = Response.find(params[:id])
    if @response.update(response_params)
      # Broadcast success message
      @response.prompt_instance.update(status: "submitted")

      Turbo::StreamsChannel.broadcast_replace_to(
        @response.player,
        target: "prompt-instance-#{@response.prompt_instance.id}",
        partial: "responses/submission_success",
        locals: { response: @response }
      )
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
