class CreateTriviaPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_packs do |t|
      t.string :name
      t.string :game_type, default: "Speed Trivia"
      t.boolean :is_default
      t.integer :status, default: 0
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
