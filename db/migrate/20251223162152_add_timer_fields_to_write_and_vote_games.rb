class AddTimerFieldsToWriteAndVoteGames < ActiveRecord::Migration[8.1]
  def change
    add_column :write_and_vote_games, :round_ends_at, :datetime
    add_column :write_and_vote_games, :timer_duration, :integer, default: 30
  end
end
