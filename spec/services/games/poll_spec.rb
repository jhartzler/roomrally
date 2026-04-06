require "rails_helper"

RSpec.describe Games::Poll do
  let(:room) { create(:room, game_type: "Poll Game") }
  let(:pack) { create(:poll_pack) }
  let!(:q1) { create(:poll_question, poll_pack: pack, options: ["dogs", "cats"]) }
  let!(:q2) { create(:poll_question, poll_pack: pack, options: ["pizza", "tacos"]) }
  let(:players) { create_list(:player, 3, room:) }
  let(:game) { room.current_game.reload }

  before do
    allow(GameBroadcaster).to receive(:broadcast_game_start)
    allow(GameBroadcaster).to receive(:broadcast_stage)
    allow(GameBroadcaster).to receive(:broadcast_hand)
    allow(GameBroadcaster).to receive(:broadcast_host_controls)
    room.update!(poll_pack: pack)
    players # create players
    Games::Poll.game_started(room:, question_count: 2, scoring_mode: "majority",
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
      Games::Poll.start_question(game:)
      expect(game.reload).to be_answering
    end
  end

  describe ".submit_answer" do
    before { Games::Poll.start_question(game:) }

    it "creates a PollAnswer" do
      expect {
        Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      }.to change(PollAnswer, :count).by(1)
    end

    it "is idempotent — second submission returns existing answer" do
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      expect {
        Games::Poll.submit_answer(game:, player: players[0], selected_option: "cats")
      }.not_to change(PollAnswer, :count)
    end
  end

  describe ".close_round — majority mode" do
    before do
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "transitions to reviewing" do
      Games::Poll.close_round(game:)
      expect(game.reload).to be_reviewing
    end

    it "awards points to majority players only" do
      Games::Poll.close_round(game:)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: q1)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: q1)
      expect(dogs_answers.map(&:points_awarded)).to all(be > 0)
      expect(cats_answer.points_awarded).to eq(0)
    end

    it "awards no points on perfect tie" do
      game2 = create(:poll_game, poll_pack: pack, scoring_mode: "majority")
      room.update!(current_game: game2)
      Games::Poll.start_question(game: game2)
      p1, p2 = players[0..1]
      Games::Poll.submit_answer(game: game2, player: p1, selected_option: "dogs")
      Games::Poll.submit_answer(game: game2, player: p2, selected_option: "cats")
      Games::Poll.close_round(game: game2)
      answers = PollAnswer.where(poll_game: game2, poll_question: q1)
      expect(answers.map(&:points_awarded)).to all(eq(0))
    end
  end

  describe ".close_round — minority mode" do
    before do
      game.update!(scoring_mode: "minority")
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "awards points to the minority player only" do
      Games::Poll.close_round(game:)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: q1)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: q1)
      expect(cats_answer.points_awarded).to be > 0
      expect(dogs_answers.map(&:points_awarded)).to all(eq(0))
    end
  end

  describe ".set_host_answer — host_choose mode" do
    before do
      game.update!(scoring_mode: "host_choose")
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "cats")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
      Games::Poll.close_round(game:)
    end

    it "sets host_chosen_answer and scores accordingly" do
      Games::Poll.set_host_answer(game:, answer: "cats")
      game.reload
      expect(game.host_chosen_answer).to eq("cats")
      cats_answers = PollAnswer.where(player: players[1..2], poll_question: q1)
      dogs_answer  = PollAnswer.find_by(player: players[0], poll_question: q1)
      expect(cats_answers.map(&:points_awarded)).to all(be > 0)
      expect(dogs_answer.points_awarded).to eq(0)
    end
  end
end
