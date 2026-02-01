class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack

  validates :body, presence: true
  validates :correct_answer, presence: true
end
