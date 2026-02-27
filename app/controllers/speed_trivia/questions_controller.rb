# frozen_string_literal: true

module SpeedTrivia
  class QuestionsController < ApplicationController
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def create
      Games::SpeedTrivia.start_question(game: @game)

      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_back fallback_location: room_backstage_path(@game.room) }
      end
    end

    private

    def set_game
      @game = SpeedTriviaGame.find(params[:speed_trivia_game_id])
    end
  end
end
