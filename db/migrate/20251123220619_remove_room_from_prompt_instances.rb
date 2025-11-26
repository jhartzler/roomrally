class RemoveRoomFromPromptInstances < ActiveRecord::Migration[8.1]
  def change
    remove_reference :prompt_instances, :room, null: false, foreign_key: true
  end
end
