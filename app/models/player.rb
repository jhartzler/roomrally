class Player < ApplicationRecord
  belongs_to :room

  validates :name, presence: true
  validates :session_id, presence: true, uniqueness: true

  attribute :score, :integer, default: 0
end
