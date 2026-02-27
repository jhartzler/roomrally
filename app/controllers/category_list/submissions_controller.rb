# frozen_string_literal: true

module CategoryList
  class SubmissionsController < ApplicationController
    before_action :set_game

    def create
      player = current_player
      unless player
        redirect_to root_path, alert: "You must be a player to submit answers."
        return
      end

      Games::CategoryList.submit_answers(
        game: @game,
        player:,
        answers_params: submission_params
      )

      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to room_hand_path(@game.room) }
      end
    end

    private

    def set_game
      @game = CategoryListGame.find(params[:category_list_game_id])
    end

    def submission_params
      allowed_keys = @game.current_round_categories.pluck(:id).map(&:to_s)
      params.require(:answers).permit(*allowed_keys).to_h
    end
  end
end
