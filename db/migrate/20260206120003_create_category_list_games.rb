class CreateCategoryListGames < ActiveRecord::Migration[8.1]
  def change
    create_table :category_list_games do |t|
      t.string :status
      t.string :current_letter
      t.integer :current_round, default: 1
      t.integer :total_rounds, default: 3
      t.integer :categories_per_round, default: 6
      t.references :category_pack, null: true, foreign_key: true
      t.boolean :show_instructions, default: true, null: false
      t.boolean :timer_enabled, default: false, null: false
      t.integer :timer_duration
      t.integer :timer_increment, default: 90, null: false
      t.datetime :round_ends_at
      t.string :used_letters, array: true, default: []

      t.timestamps
    end
  end
end
