class TriviaAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :trivia_question_instance

  def determine_correctness
    self.correct = trivia_question_instance.correct_answers.include?(selected_option)
  end

  def calculate_points(time_limit:, round_started_at:, round_closed_at:)
    return 0 unless correct?

    deadline = round_closed_at + SpeedTriviaGame::GRACE_PERIOD
    return 0 if submitted_at > deadline

    elapsed = [ submitted_at - round_started_at, 0 ].max
    # Formula: Max * (1 - (elapsed / time_limit) * Decay)
    raw_points = SpeedTriviaGame::MAXIMUM_POINTS * (1 - (elapsed / time_limit.to_f) * SpeedTriviaGame::DECAY_FACTOR)
    [ raw_points.floor, SpeedTriviaGame::MINIMUM_POINTS ].max
  end
end
