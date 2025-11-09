class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.integer :score, default: 0, null: false
      t.string :session_id, null: false
      t.references :room, null: false, foreign_key: true

      t.timestamps
    end
    add_index :players, :session_id, unique: true
  end
end
