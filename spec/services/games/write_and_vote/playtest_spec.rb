require 'rails_helper'

RSpec.describe Games::WriteAndVote::Playtest do
  let(:room) { create(:room, game_type: "Write And Vote") }
  let(:players) do
    3.times.map { |i| create(:player, room:, name: "Player #{i + 1}") }
  end
  let(:prompt_pack) { create(:prompt_pack, :default) }

  before do
    room.update!(host: players.first)
    # Create enough prompts for the game
    6.times { |i| create(:prompt, body: "Prompt #{i + 1}", prompt_pack:) }
  end

  def start_game!
    room.start_game!
    Games::WriteAndVote.game_started(room:, show_instructions: false)
    room.current_game
  end

  describe ".bot_act" do
    context "when game is in writing state" do
      it "submits responses for all players" do
        game = start_game!
        expect(game.status).to eq("writing")

        blank_count = game.responses.where(body: [ nil, "" ]).count
        expect(blank_count).to be > 0

        described_class.bot_act(game:, exclude_player: nil)
        game.reload

        expect(game.responses.where(body: [ nil, "" ]).count).to eq(0)
      end

      it "excludes specified player from bot actions" do
        game = start_game!
        excluded = players.first

        described_class.bot_act(game:, exclude_player: excluded)
        game.reload

        excluded_blank = game.responses
                             .joins(:prompt_instance)
                             .where(player: excluded, prompt_instances: { round: game.round })
                             .where(body: [ nil, "" ])
                             .count
        expect(excluded_blank).to be > 0
      end

      it "transitions to voting when all responses submitted" do
        game = start_game!
        described_class.bot_act(game:, exclude_player: nil)
        game.reload

        expect(game.status).to eq("voting")
      end
    end

    context "when game is in voting state" do
      it "casts votes for all players on the current prompt" do
        game = start_game!
        described_class.bot_act(game:, exclude_player: nil) # submit all responses
        game.reload
        expect(game.status).to eq("voting")

        current_prompt = game.current_round_prompts.order(:id)[game.current_prompt_index]
        votes_before = Vote.where(response: current_prompt.responses).count

        described_class.bot_act(game:, exclude_player: nil)

        votes_after = Vote.where(response: current_prompt.responses).count
        expect(votes_after).to be > votes_before
      end
    end

    context "when game is in a non-actionable state" do
      it "does nothing for finished games" do
        game = start_game!
        game.update!(status: "finished")
        expect { described_class.bot_act(game:, exclude_player: nil) }.not_to raise_error
      end
    end
  end

  describe ".advance" do
    it "transitions from instructions to writing" do
      room.start_game!
      Games::WriteAndVote.game_started(room:, show_instructions: true)
      game = room.current_game
      expect(game.status).to eq("instructions")

      described_class.advance(game:)
      game.reload

      expect(game.status).to eq("writing")
    end

    it "does nothing for non-advanceable states" do
      game = start_game!
      expect(game.status).to eq("writing")
      described_class.advance(game:)
      game.reload
      expect(game.status).to eq("writing")
    end
  end

  describe ".auto_play_step" do
    it "advances from instructions" do
      room.start_game!
      Games::WriteAndVote.game_started(room:, show_instructions: true)
      game = room.current_game

      described_class.auto_play_step(game:)
      game.reload

      expect(game.status).to eq("writing")
    end

    it "submits bot responses during writing" do
      game = start_game!
      described_class.auto_play_step(game:)
      game.reload

      expect(game.status).to eq("voting")
    end
  end

  describe ".dashboard_actions" do
    it "returns Start Game for lobby" do
      actions = described_class.dashboard_actions("lobby")
      expect(actions.first[:label]).to eq("Start Game")
      expect(actions.first[:action]).to eq(:start)
    end

    it "returns Skip Instructions for instructions" do
      actions = described_class.dashboard_actions("instructions")
      expect(actions.first[:label]).to eq("Skip Instructions")
    end

    it "returns bot submit for writing" do
      actions = described_class.dashboard_actions("writing")
      expect(actions.first[:label]).to eq("Bots: Submit Responses")
      expect(actions.first[:action]).to eq(:bot_act)
    end

    it "returns bot vote for voting" do
      actions = described_class.dashboard_actions("voting")
      expect(actions.first[:label]).to eq("Bots: Cast Votes")
    end

    it "returns empty for finished" do
      expect(described_class.dashboard_actions("finished")).to eq([])
    end
  end

  describe ".progress_label" do
    it "shows round progress" do
      game = start_game!
      expect(described_class.progress_label(game:)).to eq("Round 1 of 2")
    end
  end
end
