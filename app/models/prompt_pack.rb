class PromptPack < ApplicationRecord
  belongs_to :user
  has_many :prompts

  validates :name, presence: true
  validates :game_type, presence: true
end
