class Player < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :room
  has_many :responses, dependent: :destroy

  validates :name, presence: true
  validates :session_id, presence: true, uniqueness: true

  attribute :score, :integer, default: 0
end
