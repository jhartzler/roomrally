class PromptInstance < ApplicationRecord
  belongs_to :room
  belongs_to :prompt
  has_many :responses, dependent: :destroy
end
