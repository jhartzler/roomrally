module SpeedTrivia
  class AdvancementsController < ApplicationController
    include RendersHand

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

    def authorize_host
      room = @game.room
      authorized = (current_player && current_player == room.host) ||
                   (current_user && current_user == room.user)

      return if authorized

      if current_player
        redirect_to room_hand_path(room), alert: "Only the host can control the game."
      else
        redirect_to root_path, alert: "You are not authorized to control this game."
      end
    end
  end
end
