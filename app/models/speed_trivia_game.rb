class SpeedTriviaGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  # Scoring Configuration
  MAXIMUM_POINTS = 1000
  MINIMUM_POINTS = 100
  DECAY_FACTOR = 0.9 # Score decays from 1000 to 100 over round duration
  GRACE_PERIOD = 0.5.seconds
  SCORE_REVEAL_DELAY = 5 # seconds to show answer before auto-advancing to scores

  attr_accessor :previous_top_player_ids

  has_one :room, as: :current_game
  belongs_to :trivia_pack, optional: true
  has_many :trivia_question_instances, dependent: :destroy
  has_many :trivia_answers, through: :trivia_question_instances
  has_many :game_events, as: :eventable, dependent: :destroy

  def self.supports_response_moderation?
    false
  end

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    state :waiting
    state :answering
    state :reviewing
    state :finished

    event :start_game do
      transitions from: :instructions, to: :waiting
    end

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
      transitions from: [ :instructions, :waiting, :answering, :reviewing ], to: :finished
    end
  end

  def has_scoreable_data?
    trivia_answers.exists?
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
    players_count = room&.players&.active_players&.count || 0
    submitted_count >= players_count && players_count > 0
  end

  def calculate_scores!
    room.players.active_players.each do |player|
      score = total_points_for(player)
      player.update!(score:)
    end
  end

  def total_points_for(player)
    trivia_answers.where(player:).sum(:points_awarded)
  end

  # Precomputed score data for the reviewing hand view.
  # Returns everything the view needs to render the score reveal
  # without doing any score logic itself.
  def score_reveal_for(player:)
    question = current_question
    answer = question&.trivia_answers&.find_by(player:)
    round_points = answer&.points_awarded.to_i
    total = total_points_for(player)

    players = room.players.active_players.to_a
    points_by_player = question&.trivia_answers&.each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i } || {}
    ranked_now  = players.sort_by { |p| -p.score }
    ranked_prev = players.sort_by { |p| -(p.score - points_by_player.fetch(p.id, 0)) }
    rank     = ranked_now.index  { |p| p.id == player.id }.to_i + 1
    prev_rank = ranked_prev.index { |p| p.id == player.id }.to_i + 1

    {
      answer:,
      correct_answers: question&.correct_answers || [],
      round_points:,
      score_from: total - round_points,
      score_to: total,
      rank:,
      rank_improved: rank <= prev_rank
    }
  end

  # For HasRoundTimer compatibility - use question index as "round"
  def round
    current_question_index
  end

  def process_timeout(job_question_index, step_number)
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
