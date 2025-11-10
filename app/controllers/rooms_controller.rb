class RoomsController < ApplicationController
  def create
    room = Room.create!
    redirect_to join_room_path(room)
  end

  def hand
    @room = Room.find_by!(code: params[:code])
    @player = Player.find_by!(session_id: session[:player_session_id])
  end
end
