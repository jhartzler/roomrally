class CreateTriviaQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_questions do |t|
      t.text :body
      t.string :correct_answer
      t.jsonb :options
      t.references :trivia_pack, null: false, foreign_key: true

      t.timestamps
    end
  end
end
