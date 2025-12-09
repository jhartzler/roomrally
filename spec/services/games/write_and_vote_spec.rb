# spec/services/games/write_and_vote_spec.rb
require 'rails_helper'

RSpec.describe Games::WriteAndVote do
  describe '.game_started' do
    let(:room) { create(:room) }
    let!(:first_player) { create(:player, room:) }
    let!(:second_player) { create(:player, room:) }
    let!(:third_player) { create(:player, room:) }

    before do
      # Create some master prompts
      3.times { |i| create(:prompt, body: "Master Prompt #{i + 1}") }
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    it 'is idempotent (does not create duplicates if called twice)' do
      described_class.game_started(room)
      expect { described_class.game_started(room) }.not_to change(WriteAndVoteGame, :count)
    end

    it 'creates a WriteAndVoteGame and associates it with the room' do
      expect { described_class.game_started(room) }.to change(WriteAndVoteGame, :count).by(1)
      expect(room.reload.current_game).to be_a(WriteAndVoteGame)
    end

    it 'creates the correct number of prompt instances' do
      expect { described_class.game_started(room) }.to change(PromptInstance, :count).by(3)
    end

    it 'creates the correct number of responses' do
      expect { described_class.game_started(room) }.to change(Response, :count).by(6)
    end

    it 'assigns two prompts to player one' do
      described_class.game_started(room)
      expect(first_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player two' do
      described_class.game_started(room)
      expect(second_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player three' do
      described_class.game_started(room)
      expect(third_player.responses.count).to eq(2)
    end

    it 'assigns each prompt instance to two players' do
      described_class.game_started(room)
      prompt_instance_assignments = Response.group(:prompt_instance_id).count
      prompt_instance_assignments.each_value do |count|
        expect(count).to eq(2)
      end
    end

    context 'when there are not enough master prompts' do
      before do
        Prompt.destroy_all
      end

      it 'raises an error' do
        expect { described_class.game_started(room) }.to raise_error("Not enough master prompts to start the game.")
      end
    end
  end

  describe '.process_vote' do
    let(:game) { create(:write_and_vote_game, status: 'voting') }
    let(:room) { create(:room, current_game: game) }
    let(:players) { create_list(:player, 2, room:) }
    let!(:prompts) { create_list(:prompt_instance, 2, write_and_vote_game: game) }

    before do
      prompts.each do |prompt|
        players.each do |player|
          create(:response, prompt_instance: prompt, player:)
        end
      end
      # Allow calls to calculate_scores so we can spy on it
      allow(described_class).to receive(:calculate_scores).and_call_original
    end

    def cast_vote(player, prompt, response = nil)
      response ||= prompt.responses.where.not(player:).first
      create(:vote, player:, response:)
    end

    context 'when all players vote on the first prompt' do
      it 'advances to the next voting round' do
        cast_vote(players.first, prompts.first)

        expect {
          described_class.process_vote(game, cast_vote(players.last, prompts.first))
        }.to change(game, :current_prompt_index).by(1)
      end
    end

    context 'when all players vote on the last prompt of round 1' do
      before do
        game.update!(current_prompt_index: 1) # Last prompt (index 1 of 2)
      end

      it 'advances to the next game round (writing)' do
        cast_vote(players.first, prompts.last)

        expect {
          described_class.process_vote(game, cast_vote(players.last, prompts.last))
        }.to change(game, :round).by(1)
         .and change(game, :status).to("writing")
      end

      it 'calculates scores at the end of the round' do
        # Player 1 votes for Player 2's response
        cast_vote(players.first, prompts.last, prompts.last.responses.find_by(player: players.last))
        # Player 2 votes for Player 1's response
        cast_vote(players.last, prompts.last, prompts.last.responses.find_by(player: players.first))

        described_class.process_vote(game, Vote.last)
        expect(described_class).to have_received(:calculate_scores).with(game)
      end
    end

    context 'when all players vote on the last prompt of round 2' do
      let!(:round_2_prompts) { create_list(:prompt_instance, 2, write_and_vote_game: game, round: 2) }

      before do
        game.update!(round: 2, current_prompt_index: 1)
        round_2_prompts.each do |prompt|
          players.each do |player|
            create(:response, prompt_instance: prompt, player:)
          end
        end
      end

      it 'finishes the game' do
        cast_vote(players.first, round_2_prompts.last)

        expect {
          described_class.process_vote(game, cast_vote(players.last, round_2_prompts.last))
        }.to change(game, :status).to("finished")
      end

      it 'calculates scores at the end of the game' do
        # Just finish the game - logic similar to above
        cast_vote(players.first, round_2_prompts.last)
        described_class.process_vote(game, cast_vote(players.last, round_2_prompts.last))
        expect(described_class).to have_received(:calculate_scores).with(game)
      end
    end
  end

  describe '.calculate_scores' do
    let(:game) { create(:write_and_vote_game) }
    let(:room) { create(:room, current_game: game) }
    let(:first_player) { create(:player, room:) }
    let(:second_player) { create(:player, room:) }
    let!(:prompt) { create(:prompt_instance, write_and_vote_game: game) }
    # first_response created inline to reduce memoized helpers

    it 'updates player scores based on votes (500 points per vote)' do
      response = create(:response, prompt_instance: prompt, player: first_player)
      create(:vote, player: second_player, response:)
      described_class.calculate_scores(game)
      expect(first_player.reload.score).to eq(500)
    end

    it 'accumulates scores from multiple votes' do
      resp = create(:response, prompt_instance: prompt, player: first_player)
      [ second_player, create(:player, room:) ].each { |p| create(:vote, player: p, response: resp) }

      described_class.calculate_scores(game)
      expect(first_player.reload.score).to eq(1000)
    end

    it 'is idempotent' do
      create(:vote, player: second_player, response: create(:response, prompt_instance: prompt, player: first_player))
      2.times { described_class.calculate_scores(game) }
      expect(first_player.reload.score).to eq(500)
    end
  end
end
