class Player < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :room
  has_many :responses, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :trivia_answers, dependent: :destroy

  validates :name, presence: true
  validates :session_id, presence: true, uniqueness: { scope: :room_id }

  before_validation :generate_session_id, on: :create

  attribute :score, :integer, default: 0

  enum :status, {
    active: "active",
    pending_approval: "pending_approval"
  }, default: :active

  scope :active_players, -> { where(status: "active") }
  scope :pending_approval, -> { where(status: "pending_approval") }

  def kick!
    update!(status: :pending_approval)
  end

  def approve!
    update!(status: :active)
  end

  def reject!
    destroy!
  end

  private

  def generate_session_id
    self.session_id ||= SecureRandom.uuid
  end
end
