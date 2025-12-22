class PromptPack < ApplicationRecord
  belongs_to :user
  has_many :prompts, dependent: :destroy
  accepts_nested_attributes_for :prompts, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :game_type, presence: true

  enum :status, { draft: 0, live: 1 }

  def supported_players_count
    prompts.count / 2 if game_type == "Write And Vote"
  end
end
