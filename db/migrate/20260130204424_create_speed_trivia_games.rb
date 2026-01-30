class CreateSpeedTriviaGames < ActiveRecord::Migration[8.1]
  def change
    create_table :speed_trivia_games do |t|
      t.string :status
      t.integer :current_question_index, default: 0
      t.datetime :round_started_at
      t.datetime :round_closed_at
      t.integer :time_limit, default: 20
      t.references :trivia_pack, foreign_key: true

      t.timestamps
    end
  end
end
