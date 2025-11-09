class AddHostToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :host, foreign_key: { to_table: :players }
  end
end
