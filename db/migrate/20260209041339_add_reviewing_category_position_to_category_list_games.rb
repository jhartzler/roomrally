class AddReviewingCategoryPositionToCategoryListGames < ActiveRecord::Migration[8.1]
  def change
    add_column :category_list_games, :reviewing_category_position, :integer, default: 0
  end
end
