class CreateWriteAndVoteGames < ActiveRecord::Migration[8.1]
  def change
    create_table :write_and_vote_games do |t|
      t.string :status

      t.timestamps
    end
  end
end
