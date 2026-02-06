class CategoryListGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  ELIGIBLE_LETTERS = ("A".."Z").to_a - %w[Q U X Z]
  POINTS_NORMAL = 1
  POINTS_ALLITERATIVE = 2

  has_one :room, as: :current_game
  belongs_to :category_pack, optional: true
  has_many :category_instances, dependent: :destroy
  has_many :category_answers, through: :category_instances

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    state :filling
    state :reviewing
    state :scoring
    state :finished

    event :start_game do
      transitions from: :instructions, to: :filling
    end

    event :begin_review do
      transitions from: :filling, to: :reviewing
    end

    event :begin_scoring do
      transitions from: :reviewing, to: :scoring
    end

    event :begin_next_round do
      transitions from: :scoring, to: :filling
    end

    event :finish_game do
      transitions from: :scoring, to: :finished
    end
  end

  def current_round_categories
    category_instances.where(round: current_round).order(:position)
  end

  def all_answers_submitted?
    players_count = room&.players&.active_players&.count || 0
    return false if players_count.zero?

    categories_count = current_round_categories.count
    expected_answers = players_count * categories_count
    actual_answers = category_answers.joins(:category_instance)
                                     .where(category_instances: { round: current_round })
                                     .count
    actual_answers >= expected_answers
  end

  def round
    current_round
  end

  def process_timeout(round_number, _step_number)
    return unless current_round == round_number
    return unless filling?

    Games::CategoryList.handle_timeout(game: self)
  end

  def last_round?
    current_round >= total_rounds
  end
end
