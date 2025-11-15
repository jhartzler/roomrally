class CreatePromptInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_instances do |t|
      t.references :room, null: false, foreign_key: true
      t.string :body

      t.timestamps
    end
  end
end
