class TriviaPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :trivia_questions, dependent: :destroy

  include SharedScopes

  scope :global, -> { where(user_id: nil) }
  scope :accessible_by, ->(user) { where(user_id: user&.id).or(global) }

  def self.default
    find_by(is_default: true) || global.first
  end

  validates :name, presence: true

  enum :status, { draft: 0, live: 1 }
end
