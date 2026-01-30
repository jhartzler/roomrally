class CreateTriviaAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_answers do |t|
      t.string :selected_option
      t.boolean :correct
      t.integer :points_awarded, default: 0
      t.datetime :submitted_at
      t.references :player, null: false, foreign_key: true
      t.references :trivia_question_instance, null: false, foreign_key: true

      t.timestamps
    end
  end
end
