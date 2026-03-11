class TriviaPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :trivia_questions, -> { order(position: :asc, id: :asc) }, dependent: :destroy

  include SharedScopes

  scope :global, -> { where(user_id: nil) }
  scope :accessible_by, ->(user) { where(user_id: user&.id).or(global) }

  accepts_nested_attributes_for :trivia_questions, allow_destroy: true, reject_if: :reject_question?

  before_validation :set_default_name
  validate :image_count_within_limit

  def self.default
    find_by(is_default: true) || global.first
  end

  enum :status, { draft: 0, live: 1 }

  def supported_players_count
    trivia_questions.count / questions_per_player_ratio
  end

  def questions_per_player_ratio
    1 # One question per player
  end

  private

  def image_count_within_limit
    limit = PlanResolver.for(user).limits[:pack_image_limit]
    count = trivia_questions.joins(:image_attachment).count
    if count > limit
      errors.add(:base, "cannot have more than #{limit} questions with images")
    end
  end

  def reject_question?(attributes)
    # Reject if the question body is blank
    attributes["body"].blank?
  end

  def set_default_name
    self.name = "Untitled Trivia Pack" if name.blank?
  end
end
