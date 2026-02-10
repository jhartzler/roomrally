class ScoreTrackerEntry < ApplicationRecord
  belongs_to :room

  validates :name, presence: true
end
