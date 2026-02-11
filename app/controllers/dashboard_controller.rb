class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load recent activity or summary data
    # Load recent activity or summary data
    # Filter to show only the most recent active room per game type
    # We re-sort by created_at desc because the DB query orders by game_type first for DISTINCT ON
    @active_rooms = current_user.rooms.active.most_recent_by_type.sort_by(&:created_at).reverse
    @game_templates = current_user.game_templates.includes(:prompt_pack, :trivia_pack, :category_pack).order(updated_at: :desc).limit(6)
    @recent_packs = current_user.prompt_packs.includes(:prompts).recent.limit(4)
  end
end
