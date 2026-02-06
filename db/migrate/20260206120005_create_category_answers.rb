class CreateCategoryAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :category_answers do |t|
      t.string :body
      t.references :player, null: false, foreign_key: true
      t.references :category_instance, null: false, foreign_key: true
      t.string :status, default: "pending"
      t.boolean :alliterative, default: false
      t.boolean :duplicate, default: false
      t.integer :points_awarded, default: 0

      t.timestamps
    end

    add_index :category_answers, [ :player_id, :category_instance_id ], unique: true
  end
end
