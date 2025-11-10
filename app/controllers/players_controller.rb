class PlayersController < ApplicationController
  before_action :set_room, only: %i[new create]

  def new
    Rails.logger.info "Player joining room #{@room.code}"
    @player = Player.new
  end

  def create
    @player = @room.players.build(player_params)

    session_id = SecureRandom.uuid
    session[:player_session_id] = session_id
    @player.session_id = session_id

    if @player.save
      Rails.logger.info "Player #{@player.name} created in room #{@room.code}"
      @room.update!(host: @player) if @room.host.nil?

      # Broadcast the new player to all clients viewing this room
      @room.broadcast_append_to(
        @room,
        target: "player-list",
        partial: "players/player",
        locals: { player: @player }
      )

      redirect_to hand_room_path(@room)
    else
      Rails.logger.error "Player creation failed for room #{@room.code}: #{@player.errors.full_messages.join(', ')}"
      flash[:error] = @player.errors.full_messages.join(", ")
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
