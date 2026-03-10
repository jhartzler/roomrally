module ScavengerHunt
  class RevealsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      if params[:submission_id]
        submission = HuntSubmission.find(params[:submission_id])
        Games::ScavengerHunt.show_submission_on_stage(game: @game, submission:)
      else
        Games::ScavengerHunt.start_reveal(game: @game)
      end
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
