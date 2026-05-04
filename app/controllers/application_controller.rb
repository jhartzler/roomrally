class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_player
  before_action :set_sentry_context
  helper_method :current_player

  # Custom exception for moderation authorization failures
  class NotAuthorizedToModerate < StandardError; end

  # Catch authorization failures and redirect with error
  rescue_from NotAuthorizedToModerate do |exception|
    redirect_to room_hand_path(params[:code] || @room&.code), alert: "Only the room owner or host can perform this action."
  end

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

    room_code = params[:room_code] || params[:code]
    return unless room_code

    room = Room.find_by(code: room_code)
    @current_player = room&.players&.find_by(session_id: session[:player_session_id])
  end

  def current_player
    @current_player
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) || User.find_by(id: cookies.signed[:user_id])
  end
  helper_method :current_user

  def authenticate_user!
    redirect_to root_path, alert: "Please log in." unless current_user
  end

  # Check if current user/player can moderate a room (kick, approve, reject players)
  def can_moderate_room?(room)
    # Room owner (User) can moderate from backstage
    return true if current_user && room.user == current_user

    # Host player can moderate from hand view
    return true if current_player && current_player == room.host

    false
  end
  helper_method :can_moderate_room?

  # Enforce moderation permissions or raise exception
  def authorize_moderator!(room)
    return if can_moderate_room?(room)

    @room = room # Store for redirect in rescue_from
    raise NotAuthorizedToModerate
  end
end
