class CreateGameTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :game_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :game_type, null: false
      t.jsonb :settings, default: {}
      t.references :prompt_pack, foreign_key: { on_delete: :nullify }
      t.references :trivia_pack, foreign_key: { on_delete: :nullify }
      t.references :category_pack, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
  end
end
