class BackstagesController < ApplicationController
  before_action :set_room
  before_action :authenticate_user!
  before_action :authorize_owner!

  def show
    @moderation_queue = if @room.current_game.present? &&
                          @room.current_game.class.supports_response_moderation?
      Response.joins(:prompt_instance)
              .where(prompt_instances: {
                write_and_vote_game_id: @room.current_game.id,
                round: @room.current_game.round
              })
              .where(status: "submitted")
              .order(created_at: :desc)
    else
      Response.none
    end
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authorize_owner!
    unless @room.user == current_user
      redirect_to root_path, alert: "You are not authorized to view this backstage."
    end
  end
end
