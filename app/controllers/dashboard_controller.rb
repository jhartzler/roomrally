class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load recent activity or summary data
    @recent_packs = current_user.prompt_packs.order(updated_at: :desc).limit(4)
  end

  private
end
