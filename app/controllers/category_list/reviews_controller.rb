# frozen_string_literal: true

module CategoryList
  class ReviewsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def update
      if @game.room.stage_only? && @game.filling?
        Games::CategoryList.show_scores(game: @game)
      else
        Games::CategoryList.finish_review(game: @game)
      end

      render_hand
    end

    private

    def set_game
      @game = CategoryListGame.find(params[:category_list_game_id])
    end
  end
end
