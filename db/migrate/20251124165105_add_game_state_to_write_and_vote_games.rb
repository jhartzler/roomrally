class AddGameStateToWriteAndVoteGames < ActiveRecord::Migration[8.1]
  def change
    add_column :write_and_vote_games, :round, :integer, default: 1
    add_column :write_and_vote_games, :current_prompt_index, :integer, default: 0
  end
end
