# frozen_string_literal: true

class PollAnswersController < ApplicationController
  include RendersHand

  before_action :set_game

  def create
    Games::Poll.submit_answer(
      game: @game,
      player: current_player,
      selected_option: params[:poll_answer][:selected_option]
    )
    render_hand
  end

  private

  def set_game
    @game = PollGame.find(params[:poll_game_id])
  end
end
