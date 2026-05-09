class AddTeamNameToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :team_name, :string
  end
end
