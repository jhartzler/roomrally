class AddDisplayNameToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :display_name, :string
  end
end
