# frozen_string_literal: true

module CategoryList
  class ReviewNavigationsController < ApplicationController
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def update
      Games::CategoryList.navigate_review(game: @game, direction: params[:direction])

      respond_to do |format|
        format.turbo_stream { head :ok }
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
