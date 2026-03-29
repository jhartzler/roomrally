require "rails_helper"

RSpec.describe CategoryListGame, type: :model do
  describe "associations" do
    it { is_expected.to have_one(:room) }
    it { is_expected.to belong_to(:category_pack).optional }
    it { is_expected.to have_many(:category_instances).dependent(:destroy) }
    it { is_expected.to have_many(:category_answers).through(:category_instances) }
  end

  describe "AASM states" do
    let(:game) { create(:category_list_game) }

    it "starts in instructions state" do
      expect(game).to be_instructions
    end

    it "transitions from instructions to filling" do
      game.start_game!
      expect(game).to be_filling
    end

    it "transitions from filling to reviewing" do
      game.start_game!
      game.begin_review!
      expect(game).to be_reviewing
    end

    it "transitions from reviewing to scoring" do
      game.start_game!
      game.begin_review!
      game.begin_scoring!
      expect(game).to be_scoring
    end

    it "transitions from scoring to filling for next round" do
      game.start_game!
      game.begin_review!
      game.begin_scoring!
      game.begin_next_round!
      expect(game).to be_filling
    end

    it "transitions from scoring to finished" do
      game.start_game!
      game.begin_review!
      game.begin_scoring!
      game.finish_game!
      expect(game).to be_finished
    end
  end

  describe "#all_answers_submitted?" do
    let(:pack) { create(:category_pack, :default) }
    let(:game) { create(:category_list_game, category_pack: pack, current_round: 1) }
    let(:room) { create(:room, game_type: "Category List", current_game: game) }
    let!(:player1) { create(:player, room:) }
    let!(:player2) { create(:player, room:) }
    let(:category) { create(:category, category_pack: pack) }
    let!(:ci) { create(:category_instance, category_list_game: game, category:, round: 1) }

    it "returns false when not all players have submitted" do
      create(:category_answer, player: player1, category_instance: ci)
      expect(game.all_answers_submitted?).to be false
    end

    it "returns true when all players have submitted" do
      create(:category_answer, player: player1, category_instance: ci)
      create(:category_answer, player: player2, category_instance: ci)
      expect(game.all_answers_submitted?).to be true
    end
  end

  describe "#last_round?" do
    it "returns true when current_round >= total_rounds" do
      game = build(:category_list_game, current_round: 3, total_rounds: 3)
      expect(game.last_round?).to be true
    end

    it "returns false when current_round < total_rounds" do
      game = build(:category_list_game, current_round: 1, total_rounds: 3)
      expect(game.last_round?).to be false
    end
  end

  describe "#has_scoreable_data?" do
    let(:game) { create(:category_list_game) }

    it "returns false when no category answers exist" do
      expect(game.has_scoreable_data?).to be false
    end

    it "returns true when category answers exist" do
      room = create(:room, current_game: game)
      player = create(:player, room:)
      ci = create(:category_instance, category_list_game: game)
      create(:category_answer, player:, category_instance: ci)
      expect(game.has_scoreable_data?).to be true
    end
  end
end
