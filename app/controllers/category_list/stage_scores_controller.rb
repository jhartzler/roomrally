# frozen_string_literal: true

module CategoryList
  class StageScoresController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def update
      Games::CategoryList.toggle_stage_scores(game: @game)

      render_hand
    end

    private

    def set_game
      @game = CategoryListGame.find(params[:category_list_game_id])
    end
  end
end
