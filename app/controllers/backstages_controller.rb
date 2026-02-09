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
      CategoryAnswer.joins(:category_instance)
                    .where(category_instances: {
                      category_list_game_id: game.id,
                      round: game.current_round
                    })
                    .where.not(body: [ nil, "" ])
                    .where(status: "pending")
                    .includes(:player, category_instance: :category)
                    .order(created_at: :desc)
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
