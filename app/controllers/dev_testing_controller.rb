class DevTestingController < ApplicationController
  before_action :ensure_dev_environment!

  def index
    @game_types = DevPlaytest::Registry.game_types
  end

  def set_player_session
    player = Player.find(params[:id])
    session[:player_session_id] = player.session_id
    redirect_to room_hand_path(player.room)
  end

  def show_test_game
    @room = Room.find_by!(code: params[:id])
    @players = @room.players
    @game = @room.current_game
    @game_status = @game&.status || "lobby"
    @handler = DevPlaytest::Registry.handler_for(@game) if @game
    @dashboard_actions = @handler&.dashboard_actions(@game_status) || DevPlaytest::Registry.lobby_actions
    @progress_label = @handler&.progress_label(game: @game)
  end

  def create_test_game
    num_players = params[:num_players].to_i
    game_type = params[:game_type]

    room = Room.create!(game_type:, user: current_user)
    players = []
    num_players.times do |i|
      players << Player.create!(room:, name: "Player #{i + 1}")
    end

    room.update!(host: players.first)
    session[:player_session_id] = players.first.session_id

    redirect_to show_test_game_path(room)
  end

  def start_game
    room = Room.find_by!(code: params[:id])
    room.start_game!

    handler = playtest_handler_for(room)
    handler.start(room:)

    redirect_to show_test_game_path(room)
  end

  def advance
    room = Room.find_by!(code: params[:id])
    handler = playtest_handler_for(room)
    handler.advance(game: room.current_game)

    redirect_to show_test_game_path(room)
  end

  def bot_act
    room = Room.find_by!(code: params[:id])
    game = room.current_game
    human_player = params[:human_player_id] ? Player.find(params[:human_player_id]) : nil

    handler = DevPlaytest::Registry.handler_for(game)
    handler.bot_act(game:, exclude_player: human_player)

    redirect_to show_test_game_path(room)
  end

  def auto_play
    room = Room.find_by!(code: params[:id])

    # Start the game first if still in lobby
    if room.lobby?
      room.start_game!
      handler = playtest_handler_for(room)
      handler.start(room:)
      room.reload
    end

    game = room.current_game
    if game && !game.finished?
      handler = DevPlaytest::Registry.handler_for(game)
      handler.auto_play_step(game:)
    end

    redirect_to show_test_game_path(room, auto_play: params[:auto_play], interval: params[:interval])
  end

  private

  def ensure_dev_environment!
    raise ActionController::RoutingError, "Not Found" unless Rails.env.local?
  end

  def playtest_handler_for(room)
    # Look up handler by game type name since game model may not exist yet
    game_class_name = room.game_type.delete(" ") + "Game"
    handler = DevPlaytest::Registry.handler_for_class_name(game_class_name)
    raise "No dev playtest handler registered for #{room.game_type}" unless handler

    handler
  end
end
