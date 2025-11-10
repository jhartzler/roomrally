class RoomsController < ApplicationController
  before_action :set_room, only: %i[hand]

  def create
    room = Room.create!
    Rails.logger.info "Room #{room.code} created."
    redirect_to join_room_path(room)
  end

  def hand
    Rails.logger.info "Player viewing hand for room #{@room.code}"
    @player = Player.find_by!(session_id: session[:player_session_id])
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end
end
