class CreateHuntSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_submissions do |t|
      t.references :hunt_prompt_instance, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.boolean :late, default: false, null: false
      t.boolean :completed, default: false, null: false
      t.boolean :favorite, default: false, null: false
      t.text :host_notes
      t.timestamps
    end

    add_index :hunt_submissions, %i[hunt_prompt_instance_id player_id], unique: true, name: "idx_hunt_submissions_prompt_player"
  end
end
