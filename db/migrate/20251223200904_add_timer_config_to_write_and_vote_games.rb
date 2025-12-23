class AddTimerConfigToWriteAndVoteGames < ActiveRecord::Migration[8.1]
  def change
    add_column :write_and_vote_games, :timer_enabled, :boolean, default: false, null: false
    add_column :write_and_vote_games, :timer_increment, :integer, default: 60, null: false
  end
end
