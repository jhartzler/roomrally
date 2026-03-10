class HuntPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :hunt_prompts, dependent: :destroy
  accepts_nested_attributes_for :hunt_prompts, allow_destroy: true, reject_if: :all_blank

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
    self.name = "Untitled Hunt Pack" if name.blank?
  end
end
