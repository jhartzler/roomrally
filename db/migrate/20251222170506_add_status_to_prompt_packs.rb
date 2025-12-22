class AddStatusToPromptPacks < ActiveRecord::Migration[8.1]
  def change
    add_column :prompt_packs, :status, :integer, default: 0
  end
end
