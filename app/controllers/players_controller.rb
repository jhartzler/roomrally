class PlayersController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_room, only: %i[new create]
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def new
    Rails.logger.info "Player joining room #{@room.code}"
    @player = Player.new
  end

  def create
    # Check if this session already has a player in this room
    existing_player = @room.players.find_by(session_id: session[:player_session_id])

    if existing_player
      if existing_player.pending_approval?
        # They were kicked - update their name and keep them in waiting room
        old_name = existing_player.name
        if existing_player.update(name: player_params[:name])
          @player = existing_player

          # Only broadcast if name actually changed
          if old_name != existing_player.name
            GameBroadcaster.broadcast_waiting_player_updated(room: @room, player: existing_player)
          end

          redirect_to room_hand_path(@room), notice: "Name updated. Waiting for host approval..."
        else
          flash[:error] = existing_player.errors.full_messages.join(", ")
          redirect_to join_room_path(code: @room.code)
        end
      else
        # They're already in the room as an active player - just redirect them
        redirect_to room_hand_path(@room), notice: "You're already in this room!"
      end
      return
    end

    # Normal player creation flow - join immediately as active
    @player = @room.players.build(player_params)
    session_id = session[:player_session_id] || SecureRandom.uuid
    session[:player_session_id] = session_id
    @player.session_id = session_id
    @player.status = :active  # Join as active (innocent until proven guilty)

    if @player.save
      Rails.logger.info "Player #{@player.name} created in room #{@room.code}"

      # Broadcast the new player to all clients viewing this room
      GameBroadcaster.broadcast_player_joined(room: @room, player: @player)

      redirect_to room_hand_path(@room)
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

    Rails.logger.info "KICK DEBUG: session[:player_session_id]=#{session[:player_session_id]}, current_player=#{current_player.name} (id=#{current_player.id}), player_to_kick=#{player_to_kick.name} (id=#{player_to_kick.id}), host=#{room.host&.name} (id=#{room.host&.id})"

    # Check if current player is the host
    unless current_player == room.host
      Rails.logger.warn "KICK FAILED: current_player (#{current_player.name}) is not the host (#{room.host&.name})"
      redirect_to room_hand_path(room.code), alert: "Only the host can kick players."
      return
    end

    # Prevent host from kicking themselves
    if player_to_kick == current_player
      redirect_to room_hand_path(room.code), alert: "You cannot kick yourself."
      return
    end

    # Move to waiting room instead of destroying
    player_name = player_to_kick.name
    player_to_kick.kick!
    Rails.logger.info "Player #{player_name} was kicked from room #{room.code} by host #{current_player.name}"

    # Broadcast removal from active lists and add to waiting room
    GameBroadcaster.broadcast_player_kicked(room:, player: player_to_kick)

    # Redirect back to where the kick was initiated (backstage or hand view)
    redirect_back fallback_location: room_hand_path(room.code), notice: "#{player_name} has been moved to waiting room."
  end

  def approve
    player = Player.find(params[:id])
    room = player.room
    current_player = Player.find_by!(session_id: session[:player_session_id])

    unless current_player == room.host
      redirect_to room_hand_path(room.code), alert: "Only the host can approve players."
      return
    end

    player.approve!
    GameBroadcaster.broadcast_player_approved(room:, player:)

    redirect_to room_backstage_path(room.code), notice: "#{player.name} approved!"
  end

  def reject
    player = Player.find(params[:id])
    room = player.room
    current_player = Player.find_by!(session_id: session[:player_session_id])

    unless current_player == room.host
      redirect_to room_hand_path(room.code), alert: "Only the host can reject players."
      return
    end

    player_name = player.name
    player.reject!  # Permanently removes player

    redirect_to room_backstage_path(room.code), notice: "#{player_name} permanently removed."
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
