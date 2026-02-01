class GamesController < ApplicationController
  before_action :set_room
  before_action :authorize_create

  def create
    if @room.start_game!
      Rails.logger.info "Game started for room #{@room.code} by #{current_player&.name || 'Facilitator'}"

      timer_enabled = game_params[:timer_enabled] == "1"
      timer_increment = game_params[:timer_increment].to_i

      if timer_enabled && timer_increment <= 0
        @room.update(status: "lobby")
        redirect_to room_hand_path(@room.code), alert: "Could not start game: Timer increment must be greater than 0"
        return
      end

      # We need to access Publisher directly or include Wisper::Publisher in this controller
      # The original used 'subscribe' or 'publish' - checking RoomsController it included Wisper::Publisher
      # But looking at usage: publish(:game_started, ...)
      # We need to include Wisper::Publisher here too or just use the model/service if that's where it belongs.
      # The original controller had `include Wisper::Publisher` and called `publish`.
      # We will replicate that.

      broadcast_game_start(timer_enabled:, timer_increment:)

      if current_user && current_user == @room.user
        redirect_to room_backstage_path(@room.code), notice: "Game started!"
      else
        redirect_to room_hand_path(@room.code), notice: "Game started!"
      end
    else
      redirect_to room_hand_path(@room.code), alert: "Could not start game. Ensure there are at least 2 players and the game hasn't started yet."
    end
  end

  private

  include Wisper::Publisher

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authorize_create
    authorized = (current_player && current_player == @room.host) || (current_user && current_user == @room.user)

    unless authorized
      redirect_to room_hand_path(@room.code), alert: "Only the host can start the game."
    end
  end

  def game_params
    params.permit(:timer_enabled, :timer_increment)
  end

  def broadcast_game_start(timer_enabled:, timer_increment:)
    publish(:game_started, room: @room, timer_enabled:, timer_increment:)
  end
end
