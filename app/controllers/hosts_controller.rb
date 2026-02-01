class HostsController < ApplicationController
  before_action :set_room
  before_action :require_player

  def create
    # Claim host
    if @room.user.present?
      redirect_to room_hand_path(@room.code), alert: "This room has a facilitator. Player host controls are disabled."
      return
    end

    if @room.host.present?
      redirect_to room_hand_path(@room.code), alert: "There is already a host for this room."
      return
    end

    if @room.last_host_claim_at.present? && @room.last_host_claim_at > Room::HOST_CLAIM_COOLDOWN.ago
      remaining_seconds = (Room::HOST_CLAIM_COOLDOWN - (Time.current - @room.last_host_claim_at)).ceil
      redirect_to room_hand_path(@room.code), alert: "Host was recently claimed. Please wait #{remaining_seconds} seconds."
      return
    end

    @room.update!(host: current_player, last_host_claim_at: Time.current)
    Rails.logger.info "Player #{current_player.name} claimed host for room #{@room.code}"

    GameBroadcaster.broadcast_host_change(room: @room)
    redirect_to room_hand_path(@room.code), notice: "You are now the host!"
  end

  def update
    # Reassign host
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
    @room = Room.find_by!(code: params[:room_code])
  end

  def require_player
    return if current_player

    if @room
      redirect_to join_room_path(@room), alert: "You need to join the room first."
    else
      redirect_to root_path, alert: "You are not in a room."
    end
  end
end
