class ReplaceCorrectAnswerWithCorrectAnswers < ActiveRecord::Migration[8.1]
  def up
    # Add new jsonb column to trivia_questions
    add_column :trivia_questions, :correct_answers, :jsonb

    # Migrate existing data: wrap single string in array
    execute <<-SQL
      UPDATE trivia_questions
      SET correct_answers = jsonb_build_array(correct_answer)
      WHERE correct_answer IS NOT NULL
    SQL

    # Remove old column
    remove_column :trivia_questions, :correct_answer

    # Same for trivia_question_instances
    add_column :trivia_question_instances, :correct_answers, :jsonb

    execute <<-SQL
      UPDATE trivia_question_instances
      SET correct_answers = jsonb_build_array(correct_answer)
      WHERE correct_answer IS NOT NULL
    SQL

    remove_column :trivia_question_instances, :correct_answer
  end

  def down
    # Add back old column to trivia_questions
    add_column :trivia_questions, :correct_answer, :string

    execute <<-SQL
      UPDATE trivia_questions
      SET correct_answer = correct_answers->>0
      WHERE correct_answers IS NOT NULL
    SQL

    remove_column :trivia_questions, :correct_answers

    # Same for trivia_question_instances
    add_column :trivia_question_instances, :correct_answer, :string

    execute <<-SQL
      UPDATE trivia_question_instances
      SET correct_answer = correct_answers->>0
      WHERE correct_answers IS NOT NULL
    SQL

    remove_column :trivia_question_instances, :correct_answers
  end
end
