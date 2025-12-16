class DevTestingController < ApplicationController
  def index
    # This is the page where you can create a test game.
  end

  def set_player_session
    player = Player.find(params[:id])
    session[:player_session_id] = player.session_id
    redirect_to room_hand_path(player.room)
  end

  def show_test_game
    @room = Room.find_by!(code: params[:id])
    @players = @room.players
  end

  def create_test_game
    num_players = params[:num_players].to_i
    game_type = params[:game_type]

    room = Room.create!(game_type:)
    players = []
    num_players.times do |i|
      players << Player.create!(room:, name: "Player #{i + 1}")
    end

    redirect_to show_test_game_path(room)
  end
end
