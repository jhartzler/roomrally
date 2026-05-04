class AddPollPackIdToGameTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_templates, :poll_pack_id, :bigint
  end
end
