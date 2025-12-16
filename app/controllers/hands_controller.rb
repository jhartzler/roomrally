class HandsController < ApplicationController
  before_action :set_room
  before_action :require_player

  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    Rails.logger.info "Player viewing hand for room #{@room.code}"
    @player = current_player
    render :show
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def require_player
    return if current_player

    # If coming from a join link, we can't redirect to root.
    # We need to redirect to the join page.
    if @room
      redirect_to join_room_path(@room), alert: "You need to join the room first."
    else
      redirect_to root_path, alert: "You are not in a room."
    end
  end

  def room_not_found
    Rails.logger.warn "Attempted to access non-existent room hand: #{params[:room_code]}"
    redirect_to root_path, alert: "Room '#{params[:room_code]}' not found. Please check the room code and try again."
  end
end
