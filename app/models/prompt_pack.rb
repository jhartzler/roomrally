class PromptPack < ApplicationRecord
  belongs_to :user
  has_many :prompts

  validates :name, presence: true
  validates :game_type, presence: true
  validate :at_least_three_prompts, if: -> { game_type == "Write And Vote" }

  private

  def at_least_three_prompts
    return if prompts.size >= 3

    errors.add(:base, "must have at least 3 prompts for Write and Vote")
  end
end
