class AddPositionToTriviaQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :trivia_questions, :position, :integer
  end
end
