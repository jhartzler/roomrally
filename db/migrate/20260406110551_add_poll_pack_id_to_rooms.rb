class AddPollPackIdToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :poll_pack_id, :bigint
  end
end
