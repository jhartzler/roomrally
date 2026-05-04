class AddForeignKeyToFeatureEvents < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :feature_events, :features, column: :feature_name, primary_key: :name
  end
end
