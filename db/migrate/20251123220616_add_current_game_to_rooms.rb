class AddCurrentGameToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :current_game, polymorphic: true, null: true
  end
end
