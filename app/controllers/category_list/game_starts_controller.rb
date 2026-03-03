# frozen_string_literal: true

module CategoryList
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::CategoryList.start_from_instructions(game: @game)

      render_hand
    end

    private

    def set_game
      @game = CategoryListGame.find(params[:category_list_game_id])
    end
  end
end
