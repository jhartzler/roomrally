class AddPromptPackToRoomsAndGames < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :prompt_pack, null: true, foreign_key: true
    add_reference :write_and_vote_games, :prompt_pack, null: true, foreign_key: true
  end
end
