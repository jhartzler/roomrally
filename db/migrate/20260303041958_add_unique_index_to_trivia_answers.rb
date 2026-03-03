class AddUniqueIndexToTriviaAnswers < ActiveRecord::Migration[8.1]
  def change
    add_index :trivia_answers, [ :player_id, :trivia_question_instance_id ], unique: true, name: "index_trivia_answers_on_player_and_question_instance"
  end
end
