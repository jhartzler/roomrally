class AddGameTemplateToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :game_template, foreign_key: { on_delete: :nullify }
  end
end
