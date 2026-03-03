# frozen_string_literal: true

module CategoryList
  class ReviewNavigationsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def update
      Games::CategoryList.navigate_review(game: @game, direction: params[:direction])

      render_hand
    end

    private

    def set_game
      @game = CategoryListGame.find(params[:category_list_game_id])
    end
  end
end
