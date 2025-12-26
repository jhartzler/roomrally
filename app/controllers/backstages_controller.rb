class BackstagesController < ApplicationController
  before_action :set_room
  before_action :authenticate_user!
  before_action :authorize_owner!

  def show
    Rails.logger.info("DEBUG: Backstage Show - Room: #{@room.code}, Current Game ID: #{@room.current_game_id}, Current Game Type: #{@room.current_game_type}")
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authenticate_user!
    unless current_user
      redirect_to root_path, alert: "You must be logged in to access backstage."
    end
  end

  def authorize_owner!
    unless @room.user == current_user
      redirect_to root_path, alert: "You are not authorized to view this backstage."
    end
  end
end
