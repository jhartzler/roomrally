class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load recent activity or summary data
    @recent_packs = current_user.prompt_packs.order(updated_at: :desc).limit(4)
  end

  private

  def authenticate_user!
    redirect_to root_path, alert: "Please log in to access the dashboard." unless current_user
  end
end
