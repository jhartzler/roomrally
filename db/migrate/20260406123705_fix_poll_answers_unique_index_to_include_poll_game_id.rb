class FixPollAnswersUniqueIndexToIncludePollGameId < ActiveRecord::Migration[8.1]
  def change
    remove_index :poll_answers, name: "index_poll_answers_on_player_id_and_poll_question_id"
    add_index :poll_answers, [ :player_id, :poll_question_id, :poll_game_id ],
              unique: true, name: "index_poll_answers_on_player_question_and_game"
  end
end
