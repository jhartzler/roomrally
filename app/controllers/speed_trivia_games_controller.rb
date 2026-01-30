class SpeedTriviaGamesController < ApplicationController
  before_action :set_game
  before_action :authorize_host

  def start_question
    Games::SpeedTrivia.start_question(game: @game)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_back fallback_location: room_backstage_path(@game.room) }
    end
  end

  def close_round
    Games::SpeedTrivia.close_round(game: @game)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_back fallback_location: room_backstage_path(@game.room) }
    end
  end

  def next_question
    Games::SpeedTrivia.next_question(game: @game)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_back fallback_location: room_backstage_path(@game.room) }
    end
  end

  private

  def set_game
    @game = SpeedTriviaGame.find(params[:id])
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
