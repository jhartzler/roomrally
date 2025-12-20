class AddUserToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :user, null: true, foreign_key: true
  end
end
