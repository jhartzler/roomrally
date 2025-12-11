require 'rails_helper'

RSpec.describe WriteAndVoteGame, type: :model do
  describe "defaults" do
    it "has default status 'writing'" do
      game = described_class.create!
      expect(game.status).to eq("writing")
    end

    it "has default round 1" do
      game = described_class.create!
      expect(game.round).to eq(1)
    end

    it "has default current_prompt_index 0" do
      game = described_class.create!
      expect(game.current_prompt_index).to eq(0)
    end
  end

  describe "state machine" do
    let(:game) { described_class.create! }

    it "starts in writing state" do
      expect(game.status).to eq("writing")
    end

    it "allows start_voting event" do
      expect(game.may_start_voting?).to be true
    end

    it "transitions to voting on start_voting" do
      game.start_voting!
      expect(game.status).to eq("voting")
    end

    it "allows next_voting_round event in voting state" do
      game.start_voting!
      expect(game.may_next_voting_round?).to be true

      expect { game.next_voting_round! }.not_to change(game, :status)
    end

    it "increments current_prompt_index on next_voting_round" do
      game.start_voting!
      expect { game.next_voting_round! }.to change(game, :current_prompt_index).by(1)
    end

    it "transitions from voting to writing (next round)" do
      game.start_voting!
      expect(game.may_start_next_game_round?).to be true

      game.start_next_game_round!
      expect(game.status).to eq("writing")
    end

    it "increments round and resets prompt index on start_next_game_round" do
      game.start_voting!
      game.next_voting_round! # index is 1

      expect { game.start_next_game_round! }
        .to change(game, :round).by(1)
        .and change(game, :current_prompt_index).to(0)
    end

    it "transitions from voting to finished" do
      game.start_voting!
      expect(game.may_finish_game?).to be true

      game.finish_game!
      expect(game.status).to eq("finished")
    end
  end

  describe "#calculate_scores!" do
    let(:game) { create(:write_and_vote_game) }
    let(:room) { create(:room, current_game: game) }
    let(:player) { create(:player, room:, score: 0) }
    let(:prompt) { create(:prompt_instance, write_and_vote_game: game) }
    let(:response) { create(:response, player:, prompt_instance: prompt) }

    it "updates player scores based on votes" do
      create(:vote, response:, player: create(:player, room:))
      create(:vote, response:, player: create(:player, room:))

      game.calculate_scores!
      expect(player.reload.score).to eq(1000)
    end
  end

  describe "#all_responses_submitted?" do
    it "returns false if outstanding responses exist" do
      game = create(:write_and_vote_game)
      prompt = create(:prompt_instance, write_and_vote_game: game, round: game.round)
      create(:response, prompt_instance: prompt, body: nil)

      expect(game.all_responses_submitted?).to be false
    end

    it "returns true if all responses have content" do
      game = create(:write_and_vote_game)
      prompt = create(:prompt_instance, write_and_vote_game: game, round: game.round)
      create(:response, prompt_instance: prompt, body: "Answer")

      expect(game.all_responses_submitted?).to be true
    end
  end
end
