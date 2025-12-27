class BackstagesController < ApplicationController
  before_action :set_room
  before_action :authenticate_user!
  before_action :authorize_owner!

  def show
    Rails.logger.info("DEBUG: Backstage Show - Room: #{@room.code}, Current Game ID: #{@room.current_game_id}, Current Game Type: #{@room.current_game_type}")

    if @room.current_game.present?
      @moderation_queue = Response.joins(:prompt_instance)
                                  .where(prompt_instances: { write_and_vote_game_id: @room.current_game.id, round: @room.current_game.round })
                                  .where(status: "submitted")
                                  .order(created_at: :desc)
    else
      @moderation_queue = Response.none
    end
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
