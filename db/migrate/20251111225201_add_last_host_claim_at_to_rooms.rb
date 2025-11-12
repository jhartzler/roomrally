class AddLastHostClaimAtToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :last_host_claim_at, :datetime
  end
end
