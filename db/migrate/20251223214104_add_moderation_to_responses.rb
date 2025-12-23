class AddModerationToResponses < ActiveRecord::Migration[8.1]
  def change
    add_column :responses, :status, :string, default: "submitted", null: false
    add_column :responses, :rejection_reason, :text
  end
end
