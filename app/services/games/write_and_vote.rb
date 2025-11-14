# app/services/games/write_and_vote.rb
module Games
  module WriteAndVote
    def self.game_started(room)
      Rails.logger.info "WriteAndVote.game_started called for room #{room.code}"
      # The initial rendering of the prompt screen is now handled by the
      # conditional logic in the hand.html.erb view.
      # We will add back broadcasting later for real-time updates.
    end
  end
end
