class AddPromptToPromptInstances < ActiveRecord::Migration[8.1]
  def change
    add_reference :prompt_instances, :prompt, null: false, foreign_key: true
  end
end
