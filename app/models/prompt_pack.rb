class PromptPack < ApplicationRecord
  belongs_to :user, optional: true
  scope :global, -> { where(user_id: nil) }
  has_many :prompts, dependent: :destroy
  accepts_nested_attributes_for :prompts, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :game_type, presence: true

  enum :status, { draft: 0, live: 1 }

  def supported_players_count
    game_class&.supported_players_for(prompts.count)
  end

  def prompts_per_player_ratio
    game_class&.const_get(:PROMPTS_PER_PLAYER_RATIO) || 1
  end

  private

  def game_class
    # Assumes game_type is like "Write And Vote" -> "WriteAndVoteGame"
    # This naive implementation can be robustified later with a mapping
    type_name = game_type.to_s.gsub(/\s+/, "")
    "#{type_name}Game".safe_constantize
  end
end
