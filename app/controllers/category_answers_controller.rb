# frozen_string_literal: true

class CategoryAnswersController < ApplicationController
  before_action :set_answer

  def update
    game = @answer.category_instance&.category_list_game
    if game.nil?
      Sentry.capture_message(
        "CategoryAnswersController: game is nil for answer",
        level: :error,
        extra: { answer_id: @answer.id }
      )
      head :unprocessable_content
      return
    end
    room = game.room

    authorized = (current_player && current_player == room.host) ||
                 (current_user && current_user == room.user)

    unless authorized
      redirect_to root_path, alert: "Not authorized."
      return
    end

    case answer_params[:status]
    when "rejected"
      Games::CategoryList.reject_answer(answer: @answer)
    when "approved"
      Games::CategoryList.approve_answer(answer: @answer)
    when "hidden"
      Games::CategoryList.hide_answer(answer: @answer)
    when "duplicate"
      Games::CategoryList.mark_duplicate(answer: @answer)
    end

    GameBroadcaster.broadcast_stage(room:)
    GameBroadcaster.broadcast_host_controls(room:)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@answer))
      end
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
