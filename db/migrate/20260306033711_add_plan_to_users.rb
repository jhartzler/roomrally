class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :string, default: "free", null: false
  end
end
