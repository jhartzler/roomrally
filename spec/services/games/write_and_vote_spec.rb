# spec/services/games/write_and_vote_spec.rb
require 'rails_helper'

RSpec.describe Games::WriteAndVote do
  describe '.game_started' do
    it 'runs without error' do
      room = FactoryBot.build_stubbed(:room, game_type: 'Write And Vote')
      expect { described_class.game_started(room) }.not_to raise_error
    end
  end
end
