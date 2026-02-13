class AddReviewingStepToSpeedTriviaGames < ActiveRecord::Migration[8.1]
  def change
    add_column :speed_trivia_games, :reviewing_step, :integer, default: 1, null: false
  end
end
