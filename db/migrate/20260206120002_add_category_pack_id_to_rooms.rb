class AddCategoryPackIdToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :category_pack, null: true, foreign_key: true
  end
end
