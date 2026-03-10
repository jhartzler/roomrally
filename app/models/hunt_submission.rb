class HuntSubmission < ApplicationRecord
  belongs_to :hunt_prompt_instance
  belongs_to :player
  has_one_attached :media

  validates :player_id, uniqueness: { scope: :hunt_prompt_instance_id, message: "has already submitted for this prompt" }

  scope :completed, -> { where(completed: true) }
  scope :favorites, -> { where(favorite: true) }
  scope :on_time, -> { where(late: false) }

  delegate :body, :weight, to: :hunt_prompt_instance
end
