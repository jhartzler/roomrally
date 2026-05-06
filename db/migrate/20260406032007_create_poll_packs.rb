class CreatePollPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_packs do |t|
      t.string :name
      t.integer :status, default: 0
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
