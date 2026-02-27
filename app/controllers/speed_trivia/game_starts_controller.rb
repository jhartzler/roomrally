# frozen_string_literal: true

module SpeedTrivia
  class GameStartsController < ApplicationController
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def create
      Games::SpeedTrivia.start_from_instructions(game: @game)

      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html do
          if current_user && current_user == @game.room.user
            redirect_to room_backstage_path(@game.room)
          else
            redirect_to room_hand_path(@game.room)
          end
        end
      end
    end

    private

    def set_game
      @game = SpeedTriviaGame.find(params[:speed_trivia_game_id])
    end
  end
end
