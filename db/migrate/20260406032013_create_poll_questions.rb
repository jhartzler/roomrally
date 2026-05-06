class CreatePollQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_questions do |t|
      t.text :body
      t.jsonb :options
      t.integer :position
      t.references :poll_pack, null: false, foreign_key: true

      t.timestamps
    end
  end
end
