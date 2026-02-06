class AddStatusToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :status, :string, default: 'active', null: false
    add_index :players, :status
  end
end
