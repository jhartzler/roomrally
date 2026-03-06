module SpeedTrivia
  class AdvancementsController < ApplicationController
    include RendersHand
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def create
      Games::SpeedTrivia.next_question(game: @game)

      render_hand
    end

    private

    def set_game
      @game = SpeedTriviaGame.find(params[:speed_trivia_game_id])
    end
  end
end
