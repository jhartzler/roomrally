class HuntPromptInstance < ApplicationRecord
  belongs_to :scavenger_hunt_game
  belongs_to :hunt_prompt
  has_many :hunt_submissions, dependent: :destroy
  belongs_to :winner_submission, class_name: "HuntSubmission", optional: true

  scope :ordered, -> { order(:position) }

  delegate :body, :weight, to: :hunt_prompt
end
