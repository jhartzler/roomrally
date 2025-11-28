class ChangeRoundDefaultInPromptInstances < ActiveRecord::Migration[8.1]
  def change
    change_column_default :prompt_instances, :round, from: nil, to: 1
  end
end
