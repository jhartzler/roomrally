# frozen_string_literal: true

module SpeedTrivia
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::SpeedTrivia.start_from_instructions(game: @game)

      render_hand
    end

    private

    def set_game
      @game = SpeedTriviaGame.find(params[:speed_trivia_game_id])
    end
  end
end
