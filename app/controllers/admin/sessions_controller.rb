module Admin
  class SessionsController < BaseController
    def index
      # NOTE: SessionHealth.check triggers per-player queries for finished games.
      # Acceptable at current scale; add pagination or limit if room count grows.
      @rooms = Room.includes(:players, :current_game, :user)
        .where(game_type: Room::GAME_TYPES)
        .order(created_at: :desc)
      @health_flags = @rooms.each_with_object({}) do |room, hash|
        hash[room.id] = SessionHealth.check(room)
      end
    end

    def show
      @room = Room.includes(:players, :current_game, :user).find_by!(code: params[:code])
      @health_flags = SessionHealth.check(@room)
      @timeline = SessionRecap.for(@room)
    end
  end
end
