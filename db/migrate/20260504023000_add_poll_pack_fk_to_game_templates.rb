class AddPollPackFkToGameTemplates < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :game_templates, :poll_packs, on_delete: :nullify
    add_index :game_templates, :poll_pack_id, name: "index_game_templates_on_poll_pack_id"
  end
end
