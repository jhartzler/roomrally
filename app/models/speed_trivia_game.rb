class SpeedTriviaGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  # Scoring Configuration
  MAXIMUM_POINTS = 1000
  MINIMUM_POINTS = 100
  DECAY_FACTOR = 0.5 # Score drops to 50% at max time
  GRACE_PERIOD = 0.5.seconds

  has_one :room, as: :current_game
  belongs_to :trivia_pack, optional: true
  has_many :trivia_question_instances, dependent: :destroy
  has_many :trivia_answers, through: :trivia_question_instances

  aasm column: :status, whiny_transitions: false do
    state :waiting, initial: true
    state :answering
    state :reviewing
    state :finished

    event :start_question do
      transitions from: [ :waiting, :reviewing ], to: :answering, after: :record_round_start
    end

    event :close_round do
      transitions from: :answering, to: :reviewing, after: :record_round_close
    end

    event :next_question do
      transitions from: :reviewing, to: :reviewing, after: :increment_question_index
    end

    event :finish_game do
      transitions from: [ :waiting, :answering, :reviewing ], to: :finished
    end
  end

  def current_question
    trivia_question_instances.find_by(position: current_question_index)
  end

  def questions_remaining?
    current_question_index < trivia_question_instances.count - 1
  end

  def all_answers_submitted?
    return false if current_question.nil?

    submitted_count = current_question.trivia_answers.count
    players_count = room&.players&.count || 0
    submitted_count >= players_count && players_count > 0
  end

  def calculate_scores!
    room.players.each do |player|
      score = trivia_answers.where(player:).sum(:points_awarded)
      player.update!(score:)
    end
  end

  # For HasRoundTimer compatibility - use question index as "round"
  def round
    current_question_index
  end

  def process_timeout(job_question_index, _step_number)
    # Verify this timeout is still relevant (guard against race conditions)
    return unless current_question_index == job_question_index
    return unless answering?

    Games::SpeedTrivia.handle_timeout(game: self)
  end

  private

  def record_round_start
    update!(round_started_at: Time.current, round_closed_at: nil)
  end

  def record_round_close
    update!(round_closed_at: Time.current)
  end

  def increment_question_index
    increment!(:current_question_index)
  end
end
