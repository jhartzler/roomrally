module HasRoundTimer
  extend ActiveSupport::Concern

  included do
    # Ensure the model has the necessary columns before using this concern
    # valid_presence_of :round_ends_at, :timer_duration if table_exists?
  end

  # Standard Interface for Views
  # "When does the timer expire?" - Unambiguous name
  def timer_expires_at_iso8601
    round_ends_at&.iso8601
  end

  # Encapsulated Logic
  def start_timer!(duration)
    # Ensure duration is an integer
    duration_val = duration.to_i

    update!(
      timer_duration: duration_val,
      round_ends_at: duration_val.seconds.from_now
    )
  end

  def time_remaining
    return 0 unless round_ends_at
    [ round_ends_at - Time.current, 0 ].max
  end
end
