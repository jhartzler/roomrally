# frozen_string_literal: true

module CategoryList
  class ReviewsController < ApplicationController
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def update
      if @game.room.stage_only? && @game.filling?
        Games::CategoryList.show_scores(game: @game)
      else
        Games::CategoryList.finish_review(game: @game)
      end

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
      @game = CategoryListGame.find(params[:category_list_game_id])
    end
  end
end
