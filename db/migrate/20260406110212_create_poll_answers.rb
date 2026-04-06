class CreatePollAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_answers do |t|
      t.string :selected_option
      t.integer :points_awarded, default: 0
      t.datetime :submitted_at
      t.references :player, null: false, foreign_key: true
      t.references :poll_game, null: false, foreign_key: true
      t.references :poll_question, null: false, foreign_key: true

      t.timestamps
    end

    add_index :poll_answers, [ :player_id, :poll_question_id ], unique: true
  end
end
