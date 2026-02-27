# frozen_string_literal: true

# Provides host authorization for game-related controllers.
#
# Requirements:
# - @game must be set before calling authorize_host
# - @game.room must exist
#
# Authorization allows:
# - The room's host player (session player == room.host)
# - The room's facilitator/owner (current_user == room.user)
#
# NOTE: We look up the player scoped to @game.room rather than using
# current_player. set_current_player in ApplicationController requires
# params[:code] to scope the lookup; without it, it returns the first
# player with that session_id across all rooms, which fails the host
# check for players who joined via room code.
module GameHostAuthorization
  extend ActiveSupport::Concern

  private

  def authorize_host
    room = @game.room
    room_player = session[:player_session_id] ? room.players.find_by(session_id: session[:player_session_id]) : nil
    authorized = (room_player && room_player == room.host) ||
                 (current_user && current_user == room.user)

    return if authorized

    if room_player || current_player
      redirect_to room_hand_path(room), alert: "Only the host can control the game."
    else
      redirect_to root_path, alert: "You are not authorized to control this game."
    end
  end
end
