class RoomsController < ApplicationController
  def create
    room = Room.create!
    redirect_to join_room_path(room)
  end

  def join
    @room = Room.find_by!(code: params[:code])
  end
end
