class PollAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :poll_game
  belongs_to :poll_question

  validates :selected_option, presence: true

  def calculate_points(round_started_at:, round_closed_at:)
    deadline = round_closed_at + PollGame::GRACE_PERIOD
    return 0 if submitted_at > deadline

    duration = round_closed_at - round_started_at
    return PollGame::MAXIMUM_POINTS if duration <= 0

    elapsed = [ submitted_at - round_started_at, 0 ].max
    raw = PollGame::MAXIMUM_POINTS * (1 - (elapsed / duration.to_f) * PollGame::DECAY_FACTOR)
    [ raw.floor, PollGame::MINIMUM_POINTS ].max
  end
end
