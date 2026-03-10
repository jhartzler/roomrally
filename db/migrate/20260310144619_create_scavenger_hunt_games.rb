class CreateScavengerHuntGames < ActiveRecord::Migration[8.1]
  def change
    create_table :scavenger_hunt_games do |t|
      t.string :status
      t.integer :timer_duration, default: 1800
      t.boolean :timer_enabled, default: true, null: false
      t.datetime :round_ends_at
      t.integer :round, default: 1, null: false
      t.integer :currently_showing_submission_id, null: true
      t.references :hunt_pack, null: true, foreign_key: true
      t.timestamps
    end
  end
end
