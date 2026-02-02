class RoomsController < ApplicationController
  include Wisper::Publisher

  before_action :set_room, only: %i[show]
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    redirect_to room_stage_path(@room)
  end

  def create
    room = Room.create!(room_params)
    if current_user
      room.update(user: current_user)
      redirect_to room_backstage_path(room)
    else
      redirect_to room_stage_path(room)
    end
  end




  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end

  def require_player
    return if current_player

    if @room
      redirect_to join_room_path(@room), alert: "You need to join the room first."
    else
      redirect_to root_path, alert: "You are not in a room."
    end
  end

  def room_params
    permitted = params.permit(:game_type, :prompt_pack_id)
    # Only allow display_name customization for logged-in users
    permitted[:display_name] = params[:display_name] if current_user && params[:display_name].present?
    permitted
  end





  def room_not_found
    Rails.logger.warn "Attempted to access non-existent room: #{params[:code]}"
    redirect_to root_path, alert: "Room '#{params[:code]}' not found. Please check the room code and try again."
  end
end
