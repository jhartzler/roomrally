class CreateHuntPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_prompts do |t|
      t.text :body, null: false
      t.integer :weight, default: 5, null: false
      t.integer :position, default: 0, null: false
      t.references :hunt_pack, null: false, foreign_key: true
      t.timestamps
    end
  end
end
