# frozen_string_literal: true

module RendersHand
  def render_hand
    room = (@game&.room || @room || current_player&.room)&.reload
    player = current_player

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
      format.html { redirect_to room_hand_path(room) }
    end
  end
end
