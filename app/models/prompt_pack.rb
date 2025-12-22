class PromptPack < ApplicationRecord
  belongs_to :user
  has_many :prompts

  validates :name, presence: true
  validates :game_type, presence: true

  enum :status, { draft: 0, live: 1 }

  def supported_players_count
    prompts.count if game_type == "Write And Vote"
  end
end
