class FixScavengerHuntFkTypes < ActiveRecord::Migration[8.1]
  def up
    change_column :scavenger_hunt_games, :currently_showing_submission_id, :bigint
    change_column :hunt_prompt_instances, :winner_submission_id, :bigint

    add_foreign_key :scavenger_hunt_games, :hunt_submissions,
                    column: :currently_showing_submission_id,
                    on_delete: :nullify
    add_index :scavenger_hunt_games, :currently_showing_submission_id
  end

  def down
    remove_index :scavenger_hunt_games, :currently_showing_submission_id
    remove_foreign_key :scavenger_hunt_games, column: :currently_showing_submission_id

    change_column :scavenger_hunt_games, :currently_showing_submission_id, :integer
    change_column :hunt_prompt_instances, :winner_submission_id, :integer
  end
end
