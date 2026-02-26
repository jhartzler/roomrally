class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack
  has_one_attached :image, dependent: :detach

  attribute :remove_image, :string

  validates :body, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answers_must_be_valid
  validate :image_content_type_acceptable
  validate :image_size_acceptable

  after_save :purge_image_if_marked

  private

  OPTIONS_COUNT = 4
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  def purge_image_if_marked
    image.detach if remove_image == "1"
  end

  def image_content_type_acceptable
    blob = image.attachment&.blob
    return unless blob

    unless ALLOWED_IMAGE_TYPES.include?(blob.content_type)
      errors.add(:image, "must be a JPEG, PNG, WebP, or GIF")
    end
  end

  def image_size_acceptable
    blob = image.attachment&.blob
    return unless blob

    if blob.byte_size > 5.megabytes
      errors.add(:image, "must be less than 5MB")
    end
  end

  def options_must_be_array_of_four
    unless options.is_a?(Array) && options.length == OPTIONS_COUNT
      errors.add(:options, "must contain exactly #{OPTIONS_COUNT} choices")
      return
    end

    if options.any?(&:blank?)
      errors.add(:options, "must not contain blank choices")
    end
  end

  def correct_answers_must_be_valid
    unless correct_answers.is_a?(Array)
      errors.add(:correct_answers, "must have at least one selected")
      return
    end

    if correct_answers.empty?
      errors.add(:correct_answers, "must have at least one selected")
      return
    end

    unless correct_answers.all? { |a| options&.include?(a) }
      errors.add(:correct_answers, "must all be included in options")
    end
  end
end
