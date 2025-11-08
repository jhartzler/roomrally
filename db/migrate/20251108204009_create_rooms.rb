class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :code
      t.string :status

      t.timestamps
    end
    add_index :rooms, :code, unique: true
  end
end
