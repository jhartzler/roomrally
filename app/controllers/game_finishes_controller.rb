# frozen_string_literal: true

class GameFinishesController < ApplicationController
  include RendersHand
  include GameHostAuthorization

  before_action :set_game
  before_action :authorize_host

  def create
    handler = GameEventRouter.handler_for(@game.room.game_type)
    handler.finish_game!(game: @game)

    render_hand
  end

  private

  def set_game
    allowed_types = %w[SpeedTriviaGame WriteAndVoteGame CategoryListGame PollGame]
    raise ActiveRecord::RecordNotFound unless allowed_types.include?(params[:game_type])

    @game = params[:game_type].constantize.find(params[:game_id])
  end
end
