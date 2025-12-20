class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :uid
      t.string :provider
      t.string :password_digest
      t.string :image

      t.timestamps
    end
  end
end
