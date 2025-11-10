class PlayersController < ApplicationController
  def new
    Rails.logger.debug "PlayersController#new: params[:code] = #{params[:code]}"
    @room = Room.find_by!(code: params[:code])
    Rails.logger.debug "PlayersController#new: @room = #{@room.inspect}"
    @player = Player.new
  end

  def create
    @room = Room.find_by!(code: params[:room_code])
    @player = @room.players.build(player_params)

    session_id = SecureRandom.uuid
    session[:player_session_id] = session_id
    @player.session_id = session_id

    if @player.save
      @room.update!(host: @player) if @room.host.nil?

      redirect_to hand_room_path(@room)
    else
      Rails.logger.error "Player save failed: #{@player.errors.full_messages.join(", ")}"
      flash[:error] = @player.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def player_params
    params.require(:player).permit(:name)
  end
end
