class TriviaAnswersController < ApplicationController
  before_action :require_player
  before_action :set_game

  def create
    unless @game.answering?
      head :unprocessable_content
      return
    end

    selected_option = trivia_answer_params[:selected_option]

    answer = Games::SpeedTrivia.submit_answer(
      game: @game,
      player: current_player,
      selected_option:
    )

    if answer.persisted?
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to room_hand_path(@game.room) }
      end
    else
      head :unprocessable_content
    end
  end

  private

  def require_player
    return if current_player

    redirect_to root_path, alert: "You need to join a room first."
  end

  def set_game
    @game = current_player.room.current_game
    return if @game.is_a?(SpeedTriviaGame)

    head :not_found
  end

  def trivia_answer_params
    params.require(:trivia_answer).permit(:selected_option)
  end
end
