class CreateCategoryInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :category_instances do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.integer :round, null: false
      t.references :category_list_game, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
