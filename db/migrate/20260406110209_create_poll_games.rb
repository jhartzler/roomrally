class CreatePollGames < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_games do |t|
      t.string :status
      t.string :scoring_mode, null: false, default: "majority"
      t.integer :current_question_index, default: 0
      t.integer :question_count, default: 5
      t.integer :time_limit, default: 20
      t.boolean :timer_enabled, default: false
      t.integer :timer_increment
      t.string :host_chosen_answer
      t.datetime :round_started_at
      t.datetime :round_closed_at
      t.datetime :round_ends_at
      t.integer :timer_duration
      t.references :poll_pack, foreign_key: true

      t.timestamps
    end
  end
end
