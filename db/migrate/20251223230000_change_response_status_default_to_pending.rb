class ChangeResponseStatusDefaultToPending < ActiveRecord::Migration[8.0]
  def change
    change_column_default :responses, :status, "pending"
  end
end
