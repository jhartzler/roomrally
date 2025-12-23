class RoomsController < ApplicationController
  include Wisper::Publisher

  before_action :set_room, only: %i[start_game claim_host reassign_host]
  before_action :require_player, only: %i[start_game claim_host reassign_host]
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def create
    room = Room.create!(room_params)
    room.update(user: current_user) if current_user
    Rails.logger.info "Room #{room.code} created with game type: #{room.game_type}. User: #{room.user&.name || 'Anonymous'}"
    redirect_to room_stage_path(room)
  end



    def start_game
      unless current_player == @room.host
        redirect_to room_hand_path(@room.code), alert: "Only the host can start the game."
        return
      end

      if @room.start_game!
        Rails.logger.info "Game started for room #{@room.code} by host #{current_player.name}"

        timer_enabled = start_game_params[:timer_enabled] == "1"
        timer_increment = start_game_params[:timer_increment].to_i

        if timer_enabled && timer_increment <= 0
          @room.update(status: "lobby")
          redirect_to room_hand_path(@room.code), alert: "Could not start game: Timer increment must be greater than 0"
          return
        end

        publish(:game_started, room: @room, timer_enabled:, timer_increment:)
        redirect_to room_hand_path(@room.code), notice: "Game started!"
      else
        redirect_to room_hand_path(@room.code), alert: "Could not start game. Ensure there are at least 2 players and the game hasn't started yet."
      end
    end
    def claim_host
    # Claim host
    if @room.host.present?
      redirect_to room_hand_path(@room.code), alert: "There is already a host for this room."
      return
    end

    if @room.last_host_claim_at.present? && @room.last_host_claim_at > 30.seconds.ago
      remaining_seconds = (30 - (Time.current - @room.last_host_claim_at)).ceil
      redirect_to room_hand_path(@room.code), alert: "Host was recently claimed. Please wait #{remaining_seconds} seconds."
      return
    end

    @room.update!(host: current_player, last_host_claim_at: Time.current)
    Rails.logger.info "Player #{current_player.name} claimed host for room #{@room.code}"

    GameBroadcaster.broadcast_host_change(room: @room)
    redirect_to room_hand_path(@room.code), notice: "You are now the host!"
  end

  def reassign_host
    unless current_player == @room.host
      redirect_to room_hand_path(@room.code), alert: "Only the host can reassign host privileges."
      return
    end

    target_player = @room.players.find_by(id: params[:player_id])
    unless target_player
      redirect_to room_hand_path(@room.code), alert: "Player not found in this room."
      return
    end

    @room.update!(host: target_player)
    Rails.logger.info "Host reassigned from #{current_player.name} to #{target_player.name} in room #{@room.code}"

    GameBroadcaster.broadcast_host_change(room: @room)
    redirect_to room_hand_path(@room.code), notice: "Host has been reassigned to #{target_player.name}."
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:code])
  end

  def require_player
    return if current_player

    if @room
      redirect_to join_room_path(@room), alert: "You need to join the room first."
    else
      redirect_to root_path, alert: "You are not in a room."
    end
  end

  def room_params
    params.permit(:game_type)
  end

  def start_game_params
    params.permit(:timer_enabled, :timer_increment)
  end



  def room_not_found
    Rails.logger.warn "Attempted to access non-existent room: #{params[:code]}"
    redirect_to root_path, alert: "Room '#{params[:code]}' not found. Please check the room code and try again."
  end
end
