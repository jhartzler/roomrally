class AddPrimaryKeyToFeatures < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE features ADD PRIMARY KEY (name)"
    remove_index :features, :name, if_exists: true
  end

  def down
    add_index :features, :name, unique: true
    execute "ALTER TABLE features DROP CONSTRAINT features_pkey"
  end
end
