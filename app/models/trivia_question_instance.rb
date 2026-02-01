class TriviaQuestionInstance < ApplicationRecord
  belongs_to :speed_trivia_game
  belongs_to :trivia_question
  has_many :trivia_answers, dependent: :destroy

  validates :body, presence: true
  validates :correct_answer, presence: true
  validates :position, presence: true
end
