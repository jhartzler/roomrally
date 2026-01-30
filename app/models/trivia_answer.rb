class TriviaAnswer < ApplicationRecord
  GRACE_PERIOD = 0.5.seconds
  MINIMUM_POINTS = 100
  MAXIMUM_POINTS = 1000

  belongs_to :player
  belongs_to :trivia_question_instance

  def determine_correctness
    self.correct = selected_option == trivia_question_instance.correct_answer
  end

  def calculate_points(time_limit:, round_started_at:, round_closed_at:)
    return 0 unless correct?

    deadline = round_closed_at + GRACE_PERIOD
    return 0 if submitted_at > deadline

    elapsed = [ submitted_at - round_started_at, 0 ].max
    # Formula: 1000 * (1 - (elapsed / time_limit) * 0.5)
    # Decays from 1000 (instant) to 500 (at time_limit)
    raw_points = MAXIMUM_POINTS * (1 - (elapsed / time_limit.to_f) * 0.5)
    [ raw_points.floor, MINIMUM_POINTS ].max
  end
end
