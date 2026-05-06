require "rails_helper"

RSpec.describe Games::Poll do
  let(:room) { create(:room, game_type: "Poll Game") }
  let(:pack) { create(:poll_pack) }
  let!(:first_question) { create(:poll_question, poll_pack: pack, options: [ "dogs", "cats" ]) }
  let(:players) { create_list(:player, 3, room:) }
  let(:game) { room.current_game.reload }

  before do
    allow(GameBroadcaster).to receive(:broadcast_game_start)
    allow(GameBroadcaster).to receive(:broadcast_stage)
    allow(GameBroadcaster).to receive(:broadcast_hand)
    allow(GameBroadcaster).to receive(:broadcast_host_controls)
    room.update!(poll_pack: pack)
    create(:poll_question, poll_pack: pack, options: [ "pizza", "tacos" ])
    players # create players
    described_class.game_started(room:, question_count: 2, scoring_mode: "majority",
                             timer_enabled: false, show_instructions: false)
  end

  describe ".game_started" do
    it "creates a PollGame and sets it as current game" do
      expect(room.current_game).to be_a(PollGame)
    end

    it "skips instructions when show_instructions is false" do
      expect(game).to be_waiting
    end
  end

  describe ".start_question" do
    it "transitions game to answering" do
      described_class.start_question(game:)
      expect(game.reload).to be_answering
    end
  end

  describe ".submit_answer" do
    before { described_class.start_question(game:) }

    it "creates a PollAnswer" do
      expect {
        described_class.submit_answer(game:, player: players[0], selected_option: "dogs")
      }.to change(PollAnswer, :count).by(1)
    end

    it "is idempotent — second submission returns existing answer" do
      described_class.submit_answer(game:, player: players[0], selected_option: "dogs")
      expect {
        described_class.submit_answer(game:, player: players[0], selected_option: "cats")
      }.not_to change(PollAnswer, :count)
    end
  end

  describe ".close_round — majority mode" do
    before do
      described_class.start_question(game:)
      described_class.submit_answer(game:, player: players[0], selected_option: "dogs")
      described_class.submit_answer(game:, player: players[1], selected_option: "dogs")
      described_class.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "transitions to reviewing" do
      described_class.close_round(game:)
      expect(game.reload).to be_reviewing
    end

    it "awards points to majority players only" do
      described_class.close_round(game:)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: first_question)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: first_question)
      expect(dogs_answers.map(&:points_awarded)).to all(be > 0)
      expect(cats_answer.points_awarded).to eq(0)
    end

    context "when vote is perfectly tied" do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:tied_game) { create(:poll_game, poll_pack: pack, scoring_mode: "majority") }

      before do
        room.update!(current_game: tied_game)
        described_class.start_question(game: tied_game)
        described_class.submit_answer(game: tied_game, player: players[0], selected_option: "dogs")
        described_class.submit_answer(game: tied_game, player: players[1], selected_option: "cats")
        described_class.close_round(game: tied_game)
      end

      it "awards no points" do
        answers = PollAnswer.where(poll_game: tied_game, poll_question: first_question)
        expect(answers.map(&:points_awarded)).to all(eq(0))
      end
    end
  end

  describe ".close_round — minority mode" do
    before do
      game.update!(scoring_mode: "minority")
      described_class.start_question(game:)
      described_class.submit_answer(game:, player: players[0], selected_option: "dogs")
      described_class.submit_answer(game:, player: players[1], selected_option: "dogs")
      described_class.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "awards points to the minority player only" do
      described_class.close_round(game:)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: first_question)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: first_question)
      expect(cats_answer.points_awarded).to be > 0
      expect(dogs_answers.map(&:points_awarded)).to all(eq(0))
    end
  end

  describe ".set_host_answer — host_choose mode" do
    before do
      game.update!(scoring_mode: "host_choose")
      described_class.start_question(game:)
      described_class.submit_answer(game:, player: players[0], selected_option: "dogs")
      described_class.submit_answer(game:, player: players[1], selected_option: "cats")
      described_class.submit_answer(game:, player: players[2], selected_option: "cats")
      described_class.close_round(game:)
    end

    it "saves the host chosen answer" do
      described_class.set_host_answer(game:, answer: "cats")
      expect(game.reload.host_chosen_answer).to eq("cats")
    end

    it "awards points to players who matched" do
      described_class.set_host_answer(game:, answer: "cats")
      cats_answers = PollAnswer.where(player: players[1..2], poll_question: first_question)
      dogs_answer  = PollAnswer.find_by(player: players[0], poll_question: first_question)
      expect(cats_answers.map(&:points_awarded)).to all(be > 0)
      expect(dogs_answer.points_awarded).to eq(0)
    end
  end
end
