class CreateTriviaQuestionInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_question_instances do |t|
      t.text :body
      t.string :correct_answer
      t.jsonb :options
      t.integer :position
      t.references :speed_trivia_game, null: false, foreign_key: true
      t.references :trivia_question, null: false, foreign_key: true

      t.timestamps
    end
  end
end
