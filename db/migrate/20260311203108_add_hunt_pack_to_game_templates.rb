class AddHuntPackToGameTemplates < ActiveRecord::Migration[8.1]
  def change
    add_reference :game_templates, :hunt_pack, null: true, foreign_key: true
  end
end
