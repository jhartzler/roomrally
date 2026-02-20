require 'rails_helper'

RSpec.describe DevPlaytest::Registry do
  describe ".handler_for" do
    it "returns the WriteAndVote handler for a WriteAndVoteGame" do
      game = create(:write_and_vote_game)
      expect(described_class.handler_for(game)).to eq(Games::WriteAndVote::Playtest)
    end

    it "returns the SpeedTrivia handler for a SpeedTriviaGame" do
      game = create(:speed_trivia_game)
      expect(described_class.handler_for(game)).to eq(Games::SpeedTrivia::Playtest)
    end

    it "returns nil for an unregistered game type" do
      expect(described_class.handler_for(double(class: double(name: "UnknownGame")))).to be_nil
    end
  end

  describe ".handler_for_class_name" do
    it "returns handler by class name string" do
      expect(described_class.handler_for_class_name("WriteAndVoteGame")).to eq(Games::WriteAndVote::Playtest)
      expect(described_class.handler_for_class_name("SpeedTriviaGame")).to eq(Games::SpeedTrivia::Playtest)
    end
  end

  describe ".game_types" do
    it "returns registered game type display names" do
      types = described_class.game_types
      expect(types).to include("Write And Vote")
      expect(types).to include("Speed Trivia")
    end
  end

  describe ".lobby_actions" do
    it "returns a Start Game action" do
      actions = described_class.lobby_actions
      expect(actions).to eq([ { label: "Start Game", action: :start, style: :primary } ])
    end
  end
end
