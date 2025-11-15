class CreateResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :responses do |t|
      t.references :player, null: false, foreign_key: true
      t.references :prompt_instance, null: false, foreign_key: true
      t.text :body

      t.timestamps
    end
  end
end
