class HuntPrompt < ApplicationRecord
  belongs_to :hunt_pack

  validates :body, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }
end
