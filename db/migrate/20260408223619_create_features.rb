class CreateFeatures < ActiveRecord::Migration[8.0]
  def change
    create_table :features, id: false do |t|
      t.string :name, null: false
      t.boolean :enabled, null: false, default: false
    end
    add_index :features, :name, unique: true
  end
end
