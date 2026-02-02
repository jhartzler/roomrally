# frozen_string_literal: true

# Provides host authorization for game-related controllers.
#
# Requirements:
# - @game must be set before calling authorize_host
# - @game.room must exist
#
# Authorization allows:
# - The room's host player (current_player == room.host)
# - The room's facilitator/owner (current_user == room.user)
module GameHostAuthorization
  extend ActiveSupport::Concern

  private

  def authorize_host
    room = @game.room
    authorized = (current_player && current_player == room.host) ||
                 (current_user && current_user == room.user)

    return if authorized

    if current_player
      redirect_to room_hand_path(room), alert: "Only the host can control the game."
    else
      redirect_to root_path, alert: "You are not authorized to control this game."
    end
  end
end
