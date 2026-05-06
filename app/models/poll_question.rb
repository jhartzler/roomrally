class PollQuestion < ApplicationRecord
  belongs_to :poll_pack

  validates :body, presence: true
  validates :options, presence: true

  def vote_counts(poll_answers)
    options.each_with_object({}) do |option, counts|
      counts[option] = poll_answers.where(selected_option: option).count
    end
  end

  def vote_percentage(option, poll_answers)
    total = poll_answers.count
    return 0 if total.zero?

    count = poll_answers.where(selected_option: option).count
    ((count.to_f / total) * 100).round
  end
end
