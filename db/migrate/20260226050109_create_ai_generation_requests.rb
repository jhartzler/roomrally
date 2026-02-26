class CreateAiGenerationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_generation_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :pack_type, null: false
      t.integer :pack_id, null: false
      t.string :user_theme, null: false
      t.integer :status, null: false, default: 0
      t.text :raw_response
      t.string :error_message
      t.boolean :counts_against_limit, null: false, default: true
      t.jsonb :parsed_items

      t.timestamps
    end

    add_index :ai_generation_requests, [ :user_id, :created_at ]
    add_index :ai_generation_requests, :status
  end
end
