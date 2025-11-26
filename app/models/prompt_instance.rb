class PromptInstance < ApplicationRecord
  belongs_to :write_and_vote_game
  belongs_to :prompt
  has_many :responses, dependent: :destroy
end
