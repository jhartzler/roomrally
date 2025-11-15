class CreatePrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :prompts do |t|
      t.string :body

      t.timestamps
    end
  end
end
