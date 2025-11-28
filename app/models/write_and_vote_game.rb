class WriteAndVoteGame < ApplicationRecord
  include AASM

  has_one :room, as: :current_game
  has_many :prompt_instances, dependent: :destroy

  aasm column: :status, whiny_transitions: false do
    state :writing, initial: true
    state :voting
    state :finished

    event :start_voting do
      transitions from: :writing, to: :voting
    end

    event :next_voting_round do
      transitions from: :voting, to: :voting, after: :increment_prompt_index
    end

    event :start_next_game_round do
      transitions from: :voting, to: :writing, after: :setup_next_round
    end

    event :finish_game do
      transitions from: :voting, to: :finished
    end
  end

  def current_round_prompts
    prompt_instances.where(round:)
  end

  private

  def increment_prompt_index
    increment!(:current_prompt_index)
  end

  def setup_next_round
    increment!(:round)
    update!(current_prompt_index: 0)
  end
end
