class SessionsController < ApplicationController
  skip_before_action :set_current_player, only: %i[omniauth destroy]

  def omniauth
    user = User.from_omniauth(request.env["omniauth.auth"])
    if user.valid?
      is_new_user = user.previously_new_record?
      reset_session
      session[:user_id] = user.id
      Analytics.identify(
        distinct_id: "user_#{user.id}",
        properties: { name: user.name, email: user.email }
      )
      Analytics.track(
        distinct_id: "user_#{user.id}",
        event: is_new_user ? "user_signed_up" : "user_logged_in",
        properties: { provider: "google", referrer_domain: Analytics.referrer_domain(request) }
      )
      redirect_to dashboard_path, notice: "Logged in successfully!"
    else
      redirect_to root_path, alert: "Login failed."
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully."
  end
end
