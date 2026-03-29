# frozen_string_literal: true

module RendersHand
  def render_hand
    room = (@game&.room || @room || current_player&.room)&.reload
    player = current_player&.reload

    # Backstage users (authenticated as User, not Player) trigger host actions
    # that call render_hand. They don't have a #hand_screen target, and player
    # is nil. The game service already broadcast to all actual players, so just
    # acknowledge the request.
    unless player
      head :ok
      return
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.action(
          :update,
          "hand_screen",
          method: :morph,
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
      format.html { redirect_to room_hand_path(room) }
    end
  end
end
