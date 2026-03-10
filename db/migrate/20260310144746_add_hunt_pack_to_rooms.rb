class AddHuntPackToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :hunt_pack, null: true, foreign_key: true
  end
end
