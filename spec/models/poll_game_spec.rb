require "rails_helper"

RSpec.describe PollGame, type: :model do
  let(:room) { create(:room) }
  let(:pack) { create(:poll_pack) }
  let(:game) { create(:poll_game, poll_pack: pack) }

  describe "AASM states" do
    it "starts in instructions" do
      expect(game.status).to eq("instructions")
    end

    it "transitions instructions -> waiting via start_game!" do
      game.start_game!
      expect(game).to be_waiting
    end

    it "transitions waiting -> answering via start_question!" do
      game.start_game!
      game.start_question!
      expect(game).to be_answering
    end

    it "transitions answering -> reviewing via close_round!" do
      game.start_game!
      game.start_question!
      game.close_round!
      expect(game).to be_reviewing
    end

    it "transitions reviewing -> finished via finish_game!" do
      game.start_game!
      game.start_question!
      game.close_round!
      game.finish_game!
      expect(game).to be_finished
    end
  end

  describe "#questions_remaining?" do
    it "returns true when more questions follow current index" do
      create(:poll_question, poll_pack: pack)
      create(:poll_question, poll_pack: pack)
      game.update!(question_count: 2)
      expect(game.questions_remaining?).to be true
    end
  end

  describe "#majority_option" do
    let(:question) { create(:poll_question, poll_pack: pack, options: [ "dogs", "cats", "neither" ]) }
    let(:players) { create_list(:player, 3, room:) }

    it "returns the option with the most votes" do
      create(:poll_answer, poll_game: game, poll_question: question, player: players[0], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[1], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[2], selected_option: "cats")
      expect(game.majority_option(question)).to eq("dogs")
    end

    it "returns nil on a perfect tie" do
      create(:poll_answer, poll_game: game, poll_question: question, player: players[0], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[1], selected_option: "cats")
      expect(game.majority_option(question)).to be_nil
    end
  end
end
