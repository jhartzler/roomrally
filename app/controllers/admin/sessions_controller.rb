module Admin
  class SessionsController < BaseController
    def index
      @rooms = Room.includes(:players, :current_game, :user)
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
