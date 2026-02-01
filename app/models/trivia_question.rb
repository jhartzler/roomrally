class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack

  validates :body, presence: true
  validates :correct_answer, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answer_must_be_in_options

  private

  def options_must_be_array_of_four
    unless options.is_a?(Array) && options.length == 4
      errors.add(:options, "must contain exactly 4 choices")
    end
  end

  def correct_answer_must_be_in_options
    unless options&.include?(correct_answer)
      errors.add(:correct_answer, "must be one of the provided options")
    end
  end
end
