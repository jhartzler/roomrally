class PollPack < ApplicationRecord
  include SharedScopes

  belongs_to :user, optional: true
  has_many :poll_questions, dependent: :destroy
  accepts_nested_attributes_for :poll_questions, allow_destroy: true

  scope :global, -> { where(user_id: nil) }
  scope :accessible_by, ->(user) { where(user_id: user&.id).or(global) }

  enum :status, { draft: 0, live: 1 }, default: :live

  validates :name, presence: true

  def self.default
    find_by(name: "This or That") ||
      create!(name: "This or That", status: :live)
  end
end
