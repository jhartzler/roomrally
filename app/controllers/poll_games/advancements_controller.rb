# frozen_string_literal: true

module PollGames
  class AdvancementsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.next_question(game: @game)
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
