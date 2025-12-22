class AddPromptPackToPrompts < ActiveRecord::Migration[8.1]
  def change
    add_reference :prompts, :prompt_pack, null: true, foreign_key: true
  end
end
