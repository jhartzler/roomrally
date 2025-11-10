class RoomsController < ApplicationController
  before_action :set_room, only: %i[hand start_game]

  def create
    room = Room.create!
    Rails.logger.info "Room #{room.code} created."
    redirect_to join_room_path(room)
  end

  def hand
    Rails.logger.info "Player viewing hand for room #{@room.code}"
    @player = Player.find_by!(session_id: session[:player_session_id])
  end

  def start_game
    @player = Player.find_by!(session_id: session[:player_session_id])

    unless @player == @room.host
      redirect_to hand_room_path(@room.code), alert: "Only the host can start the game."
      return
    end

    @room.update!(status: "playing")
    Rails.logger.info "Game started for room #{@room.code} by host #{@player.name}"

    redirect_to hand_room_path(@room.code), notice: "Game started!"
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end
end
