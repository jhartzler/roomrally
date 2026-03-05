# frozen_string_literal: true

module WriteAndVote
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::WriteAndVote.start_from_instructions(game: @game)

      render_hand
    end

    private

    def set_game
      @game = WriteAndVoteGame.find(params[:write_and_vote_game_id])
    end
  end
end
