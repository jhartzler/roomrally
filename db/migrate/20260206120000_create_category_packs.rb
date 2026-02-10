class CreateCategoryPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :category_packs do |t|
      t.string :name
      t.string :game_type, default: "Category List"
      t.boolean :is_default, default: false
      t.integer :status, default: 0
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
