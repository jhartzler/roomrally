class AddGameTypeToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :game_type, :string, default: "Write And Vote"
  end
end
