class CreateHuntPromptInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_prompt_instances do |t|
      t.references :scavenger_hunt_game, null: false, foreign_key: true
      t.references :hunt_prompt, null: false, foreign_key: true
      t.integer :position, default: 0, null: false
      t.integer :winner_submission_id, null: true
      t.timestamps
    end
  end
end
