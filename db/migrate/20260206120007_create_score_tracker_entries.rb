class CreateScoreTrackerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :score_tracker_entries do |t|
      t.string :name, null: false
      t.integer :score, default: 0
      t.references :room, null: false, foreign_key: true

      t.timestamps
    end
  end
end
