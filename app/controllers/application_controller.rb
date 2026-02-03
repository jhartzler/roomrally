class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_player
  before_action :set_sentry_context
  helper_method :current_player

  private

  def set_sentry_context
    Sentry.set_user(id: current_user.id) if current_user

    Sentry.set_tags(player_id: current_player.id) if current_player

    room_code = current_player&.room&.code || params[:code]
    if room_code
      Sentry.set_tags(room_code:)
      Sentry.set_context("room", { code: room_code })
    end
  end

  def set_current_player
    return unless session[:player_session_id]

    @current_player = Player.find_by(session_id: session[:player_session_id])
  end

  def current_player
    @current_player
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def authenticate_user!
    redirect_to root_path, alert: "Please log in." unless current_user
  end
end
