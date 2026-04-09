class CreateFeatureEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :feature_events do |t|
      t.string :feature_name, null: false
      t.boolean :enabled, null: false
      t.datetime :created_at, null: false
    end
    add_index :feature_events, :feature_name
  end
end
