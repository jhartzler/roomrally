class RoomsController < ApplicationController
  include Wisper::Publisher

  before_action :set_room, only: %i[show start_game claim_host reassign_host]
  before_action :require_player, only: %i[claim_host reassign_host]
  before_action :authorize_start_game, only: :start_game
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    redirect_to room_stage_path(@room)
  end

  def create
    if params[:game_type].present? && !Room.available_game_types.include?(params[:game_type])
      render plain: "Game type not available", status: :unprocessable_content
      return
    end

    room = Room.create!(room_params)
    Analytics.track(
      distinct_id: current_user ? "user_#{current_user.id}" : Analytics.room_distinct_id(room),
      event: "room_created",
      properties: Analytics.room_properties(room, from_template: false)
    )
    if current_user
      room.update(user: current_user)
      redirect_to room_backstage_path(room)
    elsif mobile_request?
      redirect_to room_mobile_host_path(room)
    else
      redirect_to room_stage_path(room)
    end
  end



    def start_game
      authorized = (current_player && current_player == @room.host) || (current_user && current_user == @room.user)

      unless authorized
        redirect_to room_hand_path(@room.code), alert: "Only the host can start the game."
        return
      end

      timer_enabled = start_game_params[:timer_enabled] == "1"
      timer_increment = start_game_params[:timer_increment].to_i
      question_count = start_game_params[:question_count].to_i
      show_instructions = @room.user.nil? || start_game_params[:show_instructions] == "1"
      total_rounds = start_game_params[:total_rounds].to_i
      categories_per_round = start_game_params[:categories_per_round].to_i

      if timer_enabled && timer_increment <= 0
        redirect_to room_hand_path(@room.code), alert: "Could not start game: Timer increment must be greater than 0"
        return
      end

      if @room.game_type == "Speed Trivia" && question_count > 0
        pack = @room.trivia_pack || TriviaPack.default
        max_questions = pack.trivia_questions.count
        if question_count > max_questions
          redirect_to room_hand_path(@room.code), alert: "Could not start game: only #{max_questions} #{'question'.pluralize(max_questions)} available in this pack"
          return
        end
      end

      if @room.start_game!
        Rails.logger.info "Game started for room #{@room.code} by #{current_player&.name || 'Facilitator'}"

        publish(:game_started, room: @room, timer_enabled:, timer_increment:, question_count:, show_instructions:, total_rounds:, categories_per_round:)

        if current_user && current_user == @room.user
          redirect_to room_backstage_path(@room.code), notice: "Game started!"
        else
          redirect_to room_hand_path(@room.code), notice: "Game started!"
        end
      else
        redirect_to room_hand_path(@room.code), alert: "Could not start game. Ensure there are at least 2 players and the game hasn't started yet."
      end
    end
  def claim_host
    # Claim host
    if @room.user.present?
      redirect_to room_hand_path(@room.code), alert: "This room has a facilitator. Player host controls are disabled."
      return
    end

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
    permitted = params.permit(:game_type, :prompt_pack_id, :trivia_pack_id, :category_pack_id)
    # Only allow display_name customization for logged-in users
    permitted[:display_name] = params[:display_name] if current_user && params[:display_name].present?
    # Only allow stage_only for logged-in users
    permitted[:stage_only] = params[:stage_only] == "1" if current_user && params[:stage_only].present?
    permitted
  end

  def start_game_params
    params.permit(:timer_enabled, :timer_increment, :question_count, :show_instructions, :total_rounds, :categories_per_round)
  end



  def authorize_start_game
    return if current_user && current_user == @room.user
    return if current_player

    require_player
  end

  def mobile_request?
    request.user_agent&.match?(/Mobile|Android|iPhone|iPod/i)
  end

  def room_not_found
    Rails.logger.warn "Attempted to access non-existent room: #{params[:code]}"
    redirect_to root_path, alert: "Room '#{params[:code]}' not found. Please check the room code and try again."
  end
end
