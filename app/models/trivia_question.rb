class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack

  validates :body, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answers_must_be_valid

  private

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
