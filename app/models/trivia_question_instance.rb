class TriviaQuestionInstance < ApplicationRecord
  belongs_to :speed_trivia_game
  belongs_to :trivia_question
  has_many :trivia_answers, dependent: :destroy
  has_one_attached :image

  validates :body, presence: true
  validates :correct_answers, presence: true
  validates :position, presence: true

  def vote_counts
    trivia_answers.group(:selected_option).count
  end

  def total_votes
    trivia_answers.count
  end
end
