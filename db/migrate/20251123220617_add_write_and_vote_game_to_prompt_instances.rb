class AddWriteAndVoteGameToPromptInstances < ActiveRecord::Migration[8.1]
  def change
    add_reference :prompt_instances, :write_and_vote_game, null: true, foreign_key: true
  end
end
