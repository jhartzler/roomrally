class ChangeUserIdToNullableInPromptPacks < ActiveRecord::Migration[8.1]
  def change
    change_column_null :prompt_packs, :user_id, true
  end
end
