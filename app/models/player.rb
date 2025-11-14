class Player < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :room

  validates :name, presence: true
  validates :session_id, presence: true, uniqueness: true

  attribute :score, :integer, default: 0
end
