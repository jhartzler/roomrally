class AddTimerFieldsToSpeedTriviaGames < ActiveRecord::Migration[8.1]
  def change
    add_column :speed_trivia_games, :timer_enabled, :boolean, default: false, null: false
    add_column :speed_trivia_games, :timer_duration, :integer
    add_column :speed_trivia_games, :round_ends_at, :datetime
  end
end
