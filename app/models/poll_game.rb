class PollGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  MAXIMUM_POINTS = 1000
  MINIMUM_POINTS = 100
  DECAY_FACTOR = 0.9
  GRACE_PERIOD = 0.5.seconds

  attr_accessor :previous_top_player_ids

  has_one :room, as: :current_game
  belongs_to :poll_pack, optional: true
  has_many :poll_answers, dependent: :destroy
  has_many :game_events, as: :eventable, dependent: :destroy

  enum :scoring_mode, { majority: "majority", minority: "minority", host_choose: "host_choose" }

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

  def current_question
    questions_for_game.offset(current_question_index).first
  end

  def questions_remaining?
    current_question_index < question_count - 1
  end

  def has_scoreable_data?
    poll_answers.where.not(selected_option: nil).exists?
  end

  def all_answers_submitted?
    return false if current_question.nil?

    submitted_count = poll_answers.where(poll_question: current_question).count
    players_count = room&.players&.active_players&.count || 0
    submitted_count >= players_count && players_count > 0
  end

  def majority_option(question)
    answers = poll_answers.where(poll_question: question)
    counts = question.options.index_with { |opt| answers.where(selected_option: opt).count }
    max = counts.values.max
    return nil if max.zero?

    winners = counts.select { |_opt, count| count == max }.keys
    winners.length == 1 ? winners.first : nil
  end

  def calculate_scores!
    room.players.active_players.each do |player|
      score = poll_answers.where(player:).sum(:points_awarded)
      player.update!(score:)
    end
  end

  def total_points_for(player)
    poll_answers.where(player:).sum(:points_awarded)
  end

  def score_reveal_for(player:)
    question = current_question
    answer = question ? poll_answers.find_by(player:, poll_question: question) : nil
    round_points = answer&.points_awarded.to_i
    total = total_points_for(player)

    players = room.players.active_players.to_a
    points_by_player = poll_answers.where(poll_question: question)
      .each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i }

    ranked_now  = players.sort_by { |p| -p.score }
    ranked_prev = players.sort_by { |p| -(p.score - points_by_player.fetch(p.id, 0)) }
    rank      = ranked_now.index  { |p| p.id == player.id }.to_i + 1
    prev_rank = ranked_prev.index { |p| p.id == player.id }.to_i + 1

    winner = majority_option(question) if question
    winner = host_chosen_answer if host_choose? && host_chosen_answer.present?

    did_win = if winner.nil?
      false
    elsif host_choose?
      answer&.selected_option == winner
    elsif majority?
      answer&.selected_option == winner
    else # minority
      answer.present? && answer.selected_option != winner
    end

    {
      answer:,
      winner:,
      did_win:,
      round_points:,
      score_from: total - round_points,
      score_to: total,
      rank:,
      rank_improved: rank <= prev_rank
    }
  end

  def round
    current_question_index
  end

  def process_timeout(job_question_index, _step_number)
    return unless current_question_index == job_question_index
    return unless answering?

    Games::Poll.handle_timeout(game: self)
  end

  private

  def questions_for_game
    poll_pack&.poll_questions&.order(:position)&.limit(question_count) || PollQuestion.none
  end

  def record_round_start
    update!(round_started_at: Time.current, round_closed_at: nil, host_chosen_answer: nil)
  end

  def record_round_close
    update!(round_closed_at: Time.current)
  end

  def increment_question_index
    increment!(:current_question_index)
  end
end
