class StagesController < ApplicationController
  before_action :set_room
  before_action :authenticate_user!
  before_action :authorize_owner!

  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    Rails.logger.info "Viewing stage for room #{@room.code}"
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authorize_owner!
    unless @room.user == current_user
      redirect_to root_path, alert: "You are not authorized to view this stage."
    end
  end

  def room_not_found
    Rails.logger.warn "Attempted to access non-existent room stage: #{params[:room_code]}"
    redirect_to root_path, alert: "Room '#{params[:room_code]}' not found. Please check the room code and try again."
  end
end
