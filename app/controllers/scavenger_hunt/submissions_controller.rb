module ScavengerHunt
  class SubmissionsController < ApplicationController
    include RendersHand

    before_action :set_game

    def create
      prompt_instance = @game.hunt_prompt_instances.find(params[:hunt_prompt_instance_id])

      unless current_player
        head :unauthorized
        return
      end

      unless @game.accepts_submissions?
        head :unprocessable_entity
        return
      end

      Games::ScavengerHunt.submit_photo(
        game: @game,
        player: current_player,
        prompt_instance:,
        media: params[:media]
      )

      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
