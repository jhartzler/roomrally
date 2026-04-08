class CreateHuntPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_packs do |t|
      t.string :name
      t.references :user, null: true, foreign_key: true
      t.boolean :is_default, default: false, null: false
      t.string :game_type, default: "Scavenger Hunt"
      t.integer :status, default: 0, null: false
      t.timestamps
    end
  end
end
