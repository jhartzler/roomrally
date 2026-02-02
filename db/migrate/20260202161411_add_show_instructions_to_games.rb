class AddShowInstructionsToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :speed_trivia_games, :show_instructions, :boolean, default: true, null: false
    add_column :write_and_vote_games, :show_instructions, :boolean, default: true, null: false
  end
end
