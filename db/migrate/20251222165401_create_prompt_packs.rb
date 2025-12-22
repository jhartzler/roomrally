class CreatePromptPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_packs do |t|
      t.string :name
      t.string :game_type
      t.belongs_to :user, null: false, foreign_key: true
      t.boolean :is_default

      t.timestamps
    end
  end
end
