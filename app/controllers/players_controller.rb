class PlayersController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_room, only: %i[new create]
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

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


      # Broadcast the new player to all clients viewing this room
      GameBroadcaster.broadcast_player_joined(room: @room, player: @player)

      redirect_to hand_room_path(@room)
    else
      Rails.logger.error "Player creation failed for room #{@room.code}: #{@player.errors.full_messages.join(', ')}"
      flash[:error] = @player.errors.full_messages.join(", ")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    player_to_kick = Player.find(params[:id])
    room = player_to_kick.room
    current_player = Player.find_by!(session_id: session[:player_session_id])

    # Check if current player is the host
    unless current_player == room.host
      redirect_to hand_room_path(room.code), alert: "Only the host can kick players."
      return
    end

    # Prevent host from kicking themselves
    if player_to_kick == current_player
      redirect_to hand_room_path(room.code), alert: "You cannot kick yourself."
      return
    end

    # Kick the player
    player_name = player_to_kick.name
    player_to_kick.destroy!
    Rails.logger.info "Player #{player_name} was kicked from room #{room.code} by host #{current_player.name}"

    # Broadcast removal to all players in the room
    GameBroadcaster.broadcast_player_left(room:, player: player_to_kick)

    redirect_to hand_room_path(room.code), notice: "#{player_name} has been kicked from the room."
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end

  def player_params
    params.require(:player).permit(:name)
  end

  def room_not_found
    Rails.logger.warn "Attempted to join non-existent room: #{params[:code]}"
    redirect_to root_path, alert: "Room '#{params[:code]}' not found. Please check the room code and try again."
  end
end
