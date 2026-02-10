class AddStageOnlyToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :stage_only, :boolean, default: false, null: false
  end
end
