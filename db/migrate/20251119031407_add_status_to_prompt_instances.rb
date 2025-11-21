class AddStatusToPromptInstances < ActiveRecord::Migration[8.1]
  def change
    add_column :prompt_instances, :status, :string
  end
end
