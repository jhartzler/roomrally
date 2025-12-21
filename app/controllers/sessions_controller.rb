class SessionsController < ApplicationController
  skip_before_action :set_current_player, only: %i[omniauth destroy]

  def omniauth
    user = User.from_omniauth(request.env["omniauth.auth"])
    if user.valid?
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully!"
    else
      redirect_to root_path, alert: "Login failed."
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully."
  end
end
