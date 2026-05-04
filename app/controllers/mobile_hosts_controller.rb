class MobileHostsController < ApplicationController
  before_action :set_room
  before_action :guard_availability
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    @player = Player.new
  end

  def create
    player = nil

    @room.with_lock do
      # Re-check inside lock — guard_availability is not atomic with this action
      if @room.host.present?
        redirect_to room_hand_path(@room), alert: "This room already has a host."
        return
      end

      existing_player = @room.players.find_by(session_id: session[:player_session_id])
      if existing_player
        redirect_to room_hand_path(@room)
        return
      end

      @player = @room.players.build(player_params)
      session_id = SecureRandom.uuid
      session[:player_session_id] = session_id
      @player.session_id = session_id
      @player.status = :active

      if @player.save
        @room.update!(host: @player)
        player = @player
      end
    end

    if player
      Rails.logger.info "Mobile host #{player.name} created in room #{@room.code}"

      Analytics.track(
        distinct_id: "player_#{player.session_id}",
        event: "player_joined",
        properties: {
          room_code: @room.code,
          game_type: @room.game_type,
          mobile_host: true,
          player_count_after: @room.players.active_players.count,
          player_name: player.name
        }
      )

      GameBroadcaster.broadcast_player_joined(room: @room, player:)
      GameBroadcaster.broadcast_host_change(room: @room)

      redirect_to room_hand_path(@room)
    elsif !performed?
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def guard_availability
    if @room.user.present?
      redirect_to join_room_path(code: @room.code)
      return
    end

    if @room.host.present?
      redirect_to room_hand_path(@room), alert: "This room already has a host."
      nil
    end
  end

  def player_params
    params.require(:player).permit(:name)
  end

  def room_not_found
    redirect_to root_path, alert: "Room not found. Please check the room code and try again."
  end
end
