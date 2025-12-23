class WriteAndVoteGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  has_one :room, as: :current_game
  belongs_to :prompt_pack, optional: true
  has_many :prompt_instances, dependent: :destroy

  # Configuration
  PROMPTS_PER_PLAYER_RATIO = 2

  def self.supported_players_for(prompts_count)
    prompts_count / PROMPTS_PER_PLAYER_RATIO
  end

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

  def process_timeout(job_round_number, job_step_number)
    return unless round == job_round_number

    if status == "voting"
      return unless current_prompt_index == job_step_number
    elsif status == "writing"
      # Writing phase - verify we are still in writing
    end

    Games::WriteAndVote.handle_timeout(game: self)
  end

  def current_round_prompts
    prompt_instances.where(round:)
  end

  def calculate_scores!
    room.players.each do |player|
      score = Response.joins(:votes, :prompt_instance)
                      .where(player:)
                      .where(prompt_instances: { write_and_vote_game_id: id })
                      .count * 500
      player.update!(score:)
    end
  end

  def all_responses_submitted?
    !Response.joins(:prompt_instance)
             .where(prompt_instances: { write_and_vote_game_id: id, round: })
             .where(body: [ nil, "" ])
             .exists?
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
