class CategoryPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :categories, dependent: :destroy

  include SharedScopes

  scope :global, -> { where(user_id: nil) }
  scope :accessible_by, ->(user) { where(user_id: user&.id).or(global) }

  before_validation :set_default_name

  def self.default
    find_by(is_default: true) || global.first
  end

  enum :status, { draft: 0, live: 1 }

  private

  def set_default_name
    self.name = "Untitled Category Pack" if name.blank?
  end
end
