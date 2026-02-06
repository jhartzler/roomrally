class ChangeSessionIdIndexToScopedUniqueness < ActiveRecord::Migration[8.0]
  def change
    # Remove the old globally unique index
    remove_index :players, :session_id, if_exists: true

    # Add a new composite unique index scoped to room_id
    add_index :players, [ :session_id, :room_id ], unique: true
  end
end
