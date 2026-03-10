module ScavengerHunt
  class AwardsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.start_awards(game: @game)
      render_hand
    end

    def update
      prompt_instance = @game.hunt_prompt_instances.find(params[:id])
      submission = prompt_instance.hunt_submissions.find(params[:winner_submission_id])
      Games::ScavengerHunt.pick_winner(game: @game, prompt_instance:, submission:)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
