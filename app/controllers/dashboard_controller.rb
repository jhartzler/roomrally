class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Filter to show only the most recent active room per game type
    # We re-sort by created_at desc because the DB query orders by game_type first for DISTINCT ON
    @active_rooms = current_user.rooms.active.most_recent_by_type.sort_by(&:created_at).reverse
    @game_templates = current_user.game_templates.includes(:prompt_pack, :trivia_pack, :category_pack).order(updated_at: :desc)
    @prompt_packs_count = current_user.prompt_packs.count
    @trivia_packs_count = current_user.trivia_packs.count
    @category_packs_count = current_user.category_packs.count
  end
end
