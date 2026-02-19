require 'rails_helper'

RSpec.describe Games::SpeedTrivia::Playtest do
  let(:room) { create(:room, game_type: "Speed Trivia") }
  let(:players) do
    3.times.map { |i| create(:player, room:, name: "Player #{i + 1}") }
  end
  let(:trivia_pack) { create(:trivia_pack, :default) }

  before do
    room.update!(host: players.first)
    5.times { |i| create(:trivia_question, trivia_pack:, body: "Question #{i + 1}") }
  end

  def start_game!
    room.start_game!
    Games::SpeedTrivia.game_started(room:, show_instructions: false, timer_enabled: false)
    room.current_game
  end

  def start_answering!
    game = start_game!
    Games::SpeedTrivia.start_question(game:)
    game.reload
    game
  end

  describe ".bot_act" do
    context "when game is in answering state" do
      it "submits answers for all players" do
        game = start_answering!
        expect(game.status).to eq("answering")

        described_class.bot_act(game:, exclude_player: nil)

        answers = TriviaAnswer.where(trivia_question_instance: game.current_question)
        expect(answers.count).to eq(3)
      end

      it "excludes specified player from bot actions" do
        game = start_answering!
        excluded = players.first

        described_class.bot_act(game:, exclude_player: excluded)

        excluded_answer = TriviaAnswer.find_by(
          player: excluded,
          trivia_question_instance: game.current_question
        )
        expect(excluded_answer).to be_nil
      end

      it "does not create duplicate answers" do
        game = start_answering!
        described_class.bot_act(game:, exclude_player: nil)
        described_class.bot_act(game:, exclude_player: nil)

        answers = TriviaAnswer.where(trivia_question_instance: game.current_question)
        expect(answers.count).to eq(3)
      end
    end

    context "when game is in a non-actionable state" do
      it "does nothing in waiting state" do
        game = start_game!
        expect(game.status).to eq("waiting")
        expect { described_class.bot_act(game:, exclude_player: nil) }.not_to raise_error
      end
    end
  end

  describe ".advance" do
    it "transitions from instructions to waiting" do
      room.start_game!
      Games::SpeedTrivia.game_started(room:, show_instructions: true, timer_enabled: false)
      game = room.current_game
      expect(game.status).to eq("instructions")

      described_class.advance(game:)
      game.reload

      expect(game.status).to eq("waiting")
    end

    it "transitions from waiting to answering" do
      game = start_game!
      expect(game.status).to eq("waiting")

      described_class.advance(game:)
      game.reload

      expect(game.status).to eq("answering")
    end

    it "transitions from answering to reviewing" do
      game = start_answering!

      described_class.advance(game:)
      game.reload

      expect(game.status).to eq("reviewing")
    end

    it "transitions from reviewing to next question" do
      game = start_answering!
      Games::SpeedTrivia.close_round(game:)
      game.reload
      expect(game.status).to eq("reviewing")

      described_class.advance(game:)
      game.reload

      # next_question transitions to answering via start_question
      expect(game.status).to eq("answering")
      expect(game.current_question_index).to eq(1)
    end
  end

  describe ".auto_play_step" do
    it "starts question from waiting" do
      game = start_game!
      described_class.auto_play_step(game:)
      game.reload
      expect(game.status).to eq("answering")
    end

    it "submits answers and closes round from answering" do
      game = start_answering!
      described_class.auto_play_step(game:)
      game.reload
      expect(game.status).to eq("reviewing")
    end

    context "when game is in reviewing state" do
      def reach_reviewing!
        game = start_answering!
        Games::SpeedTrivia.close_round(game:)
        game.reload
        game
      end

      it "advances to reviewing_step 2 (score podium) when reviewing_step is 1" do
        game = reach_reviewing!
        expect(game.reviewing_step).to eq(1)

        described_class.auto_play_step(game:)
        game.reload

        expect(game.reviewing_step).to eq(2)
      end

      it "advances to next question when reviewing_step is 2" do
        game = reach_reviewing!
        game.update!(reviewing_step: 2)

        described_class.auto_play_step(game:)
        game.reload

        expect(game.current_question_index).to eq(1)
      end
    end
  end

  describe ".dashboard_actions" do
    it "returns Start Game for lobby" do
      actions = described_class.dashboard_actions("lobby")
      expect(actions.first[:label]).to eq("Start Game")
    end

    it "returns Skip Instructions for instructions" do
      actions = described_class.dashboard_actions("instructions")
      expect(actions.first[:label]).to eq("Skip Instructions")
    end

    it "returns Start Question for waiting" do
      actions = described_class.dashboard_actions("waiting")
      expect(actions.first[:label]).to eq("Start Question")
      expect(actions.first[:action]).to eq(:advance)
    end

    it "returns bot answer and close round for answering" do
      actions = described_class.dashboard_actions("answering")
      expect(actions.length).to eq(2)
      expect(actions[0][:label]).to eq("Bots: Answer")
      expect(actions[1][:label]).to eq("Close Round")
    end

    it "returns Next Question for reviewing" do
      actions = described_class.dashboard_actions("reviewing")
      expect(actions.first[:label]).to eq("Next Question")
    end

    it "returns empty for finished" do
      expect(described_class.dashboard_actions("finished")).to eq([])
    end
  end

  describe ".progress_label" do
    it "shows question progress" do
      game = start_game!
      label = described_class.progress_label(game:)
      expect(label).to eq("Question 1 of 5")
    end
  end
end
