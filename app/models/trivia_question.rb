class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack
  has_one_attached :image

  validates :body, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answers_must_be_valid
  validate :image_content_type_acceptable, if: -> { image.attached? }
  validate :image_size_acceptable, if: -> { image.attached? }

  private

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  def image_content_type_acceptable
    unless ALLOWED_IMAGE_TYPES.include?(image.blob.content_type)
      errors.add(:image, "must be a JPEG, PNG, WebP, or GIF")
    end
  end

  def image_size_acceptable
    if image.blob.byte_size > 5.megabytes
      errors.add(:image, "must be less than 5MB")
    end
  end

  def options_must_be_array_of_four
    unless options.is_a?(Array) && options.length == 4
      errors.add(:options, "must contain exactly 4 choices")
    end
  end

  def correct_answers_must_be_valid
    unless correct_answers.is_a?(Array)
      errors.add(:correct_answers, "must be an array")
      return
    end

    if correct_answers.empty?
      errors.add(:correct_answers, "must have at least one correct answer")
      return
    end

    unless correct_answers.all? { |a| options&.include?(a) }
      errors.add(:correct_answers, "must all be included in options")
    end
  end
end
