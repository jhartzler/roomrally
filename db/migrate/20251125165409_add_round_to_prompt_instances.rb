class AddRoundToPromptInstances < ActiveRecord::Migration[8.1]
  def change
    add_column :prompt_instances, :round, :integer, default: 1
  end
end
