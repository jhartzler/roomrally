# frozen_string_literal: true

class CategoryAnswersController < ApplicationController
  include GameHostAuthorization

  before_action :set_answer
  before_action :set_game
  before_action :authorize_host

  def update
    Games::CategoryList.moderate_answer(answer: @answer, status: answer_params[:status])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@answer))
      end
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

  def set_answer
    @answer = CategoryAnswer.find(params[:id])
  end

  def set_game
    @game = @answer.category_instance.category_list_game
  end

  def answer_params
    params.require(:category_answer).permit(:status)
  end
end
