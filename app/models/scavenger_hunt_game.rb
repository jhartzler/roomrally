class ScavengerHuntGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  has_one :room, as: :current_game
  belongs_to :hunt_pack, optional: true
  has_many :hunt_prompt_instances, dependent: :destroy

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    state :hunting
    state :times_up
    state :revealing
    state :awarding
    state :finished

    event :start_hunt do
      transitions from: :instructions, to: :hunting
    end

    event :end_hunting do
      transitions from: :hunting, to: :times_up
    end

    event :start_reveal do
      transitions from: %i[hunting times_up], to: :revealing
    end

    event :start_awards do
      transitions from: :revealing, to: :awarding
    end

    event :finish_game do
      transitions from: :awarding, to: :finished
    end
  end

  def process_timeout(round_number, _step_number)
    return unless round_number == round
    return unless hunting?
    Games::ScavengerHunt.handle_timeout(game: self)
  end

  def self.supports_response_moderation?
    false
  end

  def accepts_submissions?
    hunting? || times_up?
  end

  def total_prompts
    hunt_prompt_instances.count
  end

  def completed_submissions_count
    HuntSubmission.joins(:hunt_prompt_instance)
                  .where(hunt_prompt_instances: { scavenger_hunt_game_id: id })
                  .where(completed: true)
                  .count
  end
end
