module ScavengerHunt
  class CompletionsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def update
      submission = HuntSubmission.find(params[:id])

      case params[:action_type]
      when "complete"
        Games::ScavengerHunt.mark_completed(game: @game, submission:, completed: params[:value] == "true")
      when "favorite"
        Games::ScavengerHunt.mark_favorite(game: @game, submission:, favorite: params[:value] == "true")
      when "notes"
        Games::ScavengerHunt.update_host_notes(game: @game, submission:, notes: params[:notes])
      end

      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
