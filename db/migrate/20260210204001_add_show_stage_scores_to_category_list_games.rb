class AddShowStageScoresToCategoryListGames < ActiveRecord::Migration[8.1]
  def change
    add_column :category_list_games, :show_stage_scores, :boolean, default: false, null: false
  end
end
