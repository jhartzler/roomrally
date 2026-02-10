class BackstagesController < ApplicationController
  before_action :set_room
  before_action :authenticate_user!
  before_action :authorize_owner!

  def show
    @moderation_queue = build_moderation_queue
  end

  private

  def build_moderation_queue
    game = @room.current_game
    return [] unless game.present? && game.class.supports_response_moderation?

    case game
    when CategoryListGame
      [] # Moderation handled via the reviewing pane in host controls
    when WriteAndVoteGame
      Response.joins(:prompt_instance)
              .where(prompt_instances: {
                write_and_vote_game_id: game.id,
                round: game.round
              })
              .where(status: "submitted")
              .order(created_at: :desc)
    else
      []
    end
  end

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authorize_owner!
    unless @room.user == current_user
      redirect_to root_path, alert: "You are not authorized to view this backstage."
    end
  end
end
