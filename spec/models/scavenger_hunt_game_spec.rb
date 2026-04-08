require "rails_helper"

RSpec.describe ScavengerHuntGame, type: :model do
  describe "AASM states" do
    subject(:game) { described_class.new(status: "instructions") }

    it "starts in instructions state" do
      expect(game).to be_instructions
    end

    it "transitions instructions -> hunting" do
      game.start_hunt!
      expect(game).to be_hunting
    end

    it "transitions hunting -> times_up" do
      game.status = "hunting"
      game.end_hunting!
      expect(game).to be_times_up
    end

    it "transitions hunting -> revealing (skip times_up)" do
      game.status = "hunting"
      game.start_reveal!
      expect(game).to be_revealing
    end

    it "transitions times_up -> revealing" do
      game.status = "times_up"
      game.start_reveal!
      expect(game).to be_revealing
    end

    it "transitions revealing -> awarding" do
      game.status = "revealing"
      game.start_awards!
      expect(game).to be_awarding
    end

    it "transitions awarding -> finished" do
      game.status = "awarding"
      game.finish_game!
      expect(game).to be_finished
    end
  end

  describe "#accepts_submissions?" do
    it "returns true when hunting" do
      game = described_class.new(status: "hunting")
      expect(game.accepts_submissions?).to be true
    end

    it "returns true when times_up" do
      game = described_class.new(status: "times_up")
      expect(game.accepts_submissions?).to be true
    end

    it "returns false when revealing" do
      game = described_class.new(status: "revealing")
      expect(game.accepts_submissions?).to be false
    end
  end
end
