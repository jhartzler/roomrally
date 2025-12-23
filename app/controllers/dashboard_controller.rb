class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load recent activity or summary data
    @recent_packs = current_user.prompt_packs.includes(:prompts).recent.limit(4)
  end
end
