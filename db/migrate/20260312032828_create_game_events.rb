class CreateGameEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :game_events do |t|
      t.references :eventable, polymorphic: true, null: false
      t.string :event_name, null: false
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :game_events, [ :eventable_type, :eventable_id, :created_at ], name: "index_game_events_on_eventable_and_created_at"
  end
end
