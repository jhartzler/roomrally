class Vote < ApplicationRecord
  belongs_to :player
  belongs_to :response
  validate :player_cannot_vote_for_own_response
  validate :player_can_only_vote_once_per_prompt_instance
  validate :response_must_be_in_same_room

  private

  def player_cannot_vote_for_own_response
    return unless response && player

    if response.player == player
      errors.add(:base, "You cannot vote for your own response")
    end
  end

  def player_can_only_vote_once_per_prompt_instance
    return unless response && player

    existing_vote = Vote.joins(:response)
                        .where(player:)
                        .where(responses: { prompt_instance_id: response.prompt_instance_id })
                        .where.not(id:)
                        .exists?

    if existing_vote
      errors.add(:base, "You have already voted for this prompt")
    end
  end

  def response_must_be_in_same_room
    return unless response && player

    if response.room != player.room
      errors.add(:base, "You cannot vote for a response in another room")
    end
  end
end
