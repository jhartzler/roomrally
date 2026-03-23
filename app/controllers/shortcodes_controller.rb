class ShortcodesController < ApplicationController
  def show
    room = Room.find_by(code: params[:code].upcase)

    if room
      redirect_to room_stage_path(room)
    else
      redirect_to root_path, alert: "Room '#{params[:code].upcase}' not found. Please check the room code and try again."
    end
  end
end
