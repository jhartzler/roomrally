class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_player
  helper_method :current_player

  private

  def set_current_player
    return unless session[:player_session_id]

    @current_player = Player.find_by(session_id: session[:player_session_id])
  end

  def current_player
    @current_player
  end
end
