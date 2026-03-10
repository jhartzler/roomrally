module ScavengerHunt
  class FinishesController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.finish_game(game: @game)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
