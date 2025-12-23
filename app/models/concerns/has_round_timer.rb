module HasRoundTimer
  extend ActiveSupport::Concern

  included do
    # valid_presence_of :round_ends_at, :timer_duration if table_exists?
  end

  # Standard Interface for Views
  def timer_expires_at_iso8601
    round_ends_at&.iso8601
  end

  def start_timer!(duration, step_number: nil)
    duration_val = duration.to_i

    update!(
      timer_duration: duration_val,
      round_ends_at: duration_val.seconds.from_now
    )

    GameTimerJob.set(wait_until: round_ends_at).perform_later(self, round, step_number)
  end

  def time_remaining
    return 0 unless round_ends_at
    [ round_ends_at - Time.current, 0 ].max
  end
end
