# frozen_string_literal: true

class CategoryAnswersController < ApplicationController
  before_action :set_answer

  def update
    game = @answer.category_instance.category_list_game
    room = game.room

    authorized = (current_player && current_player == room.host) ||
                 (current_user && current_user == room.user)

    unless authorized
      redirect_to root_path, alert: "Not authorized."
      return
    end

    if answer_params[:status] == "rejected"
      Games::CategoryList.reject_answer(answer: @answer)
    elsif answer_params[:status] == "approved"
      Games::CategoryList.approve_answer(answer: @answer)
    end

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html do
        if current_user && current_user == room.user
          redirect_to room_backstage_path(room)
        else
          redirect_to room_hand_path(room)
        end
      end
    end
  end

  private

  def set_answer
    @answer = CategoryAnswer.find(params[:id])
  end

  def answer_params
    params.require(:category_answer).permit(:status)
  end
end
