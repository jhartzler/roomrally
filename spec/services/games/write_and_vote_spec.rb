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
      described_class.game_started(room:)
      expect { described_class.game_started(room:) }.not_to change(WriteAndVoteGame, :count)
    end

    it 'creates a WriteAndVoteGame and associates it with the room' do
      expect { described_class.game_started(room:) }.to change(WriteAndVoteGame, :count).by(1)
      expect(room.reload.current_game).to be_a(WriteAndVoteGame)
    end

    it 'creates the correct number of prompt instances' do
      expect { described_class.game_started(room:) }.to change(PromptInstance, :count).by(3)
    end

    it 'creates the correct number of responses' do
      expect { described_class.game_started(room:) }.to change(Response, :count).by(6)
    end

    it 'assigns two prompts to player one' do
      described_class.game_started(room:)
      expect(first_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player two' do
      described_class.game_started(room:)
      expect(second_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player three' do
      described_class.game_started(room:)
      expect(third_player.responses.count).to eq(2)
    end

    it 'assigns each prompt instance to two players' do
      described_class.game_started(room:)
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
        expect { described_class.game_started(room:) }.to raise_error("Not enough master prompts to start round 1.")
      end
    end
  end

  describe '.process_vote' do
    let(:game) { create(:write_and_vote_game, status: 'voting') }
    let(:room) { create(:room, current_game: game) }
    let(:players) { create_list(:player, 3, room:) }
    let!(:prompts) { create_list(:prompt_instance, 3, write_and_vote_game: game) }

    before do
      # Assign responses so that for each prompt, 2 players are authors and 1 is a voter.
      # Prompt 0: P0 & P1 are authors. P2 votes.
      # Prompt 1: P1 & P2 are authors. P0 votes.
      # Prompt 2: P2 & P0 are authors. P1 votes.
      prompts.each_with_index do |prompt, index|
        author1 = players[index]
        author2 = players[(index + 1) % 3]
        create(:response, prompt_instance: prompt, player: author1)
        create(:response, prompt_instance: prompt, player: author2)
      end
      # Allow calls to calculate_scores! on the game instance
      allow(game).to receive(:calculate_scores!)
      # Create extra prompts for Round 2 logic
      create_list(:prompt, 3)
    end

    def cast_vote(player, prompt, response = nil)
      response ||= prompt.responses.where.not(player:).first
      create(:vote, player:, response:)
    end

    context 'when the non-author votes on the first prompt' do
      it 'advances to the next voting round' do
        voter = players[2] # P2 is the voter for Prompt 0
        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, prompts.first))
        }.to change(game, :current_prompt_index).by(1)
      end
    end

    context 'when the non-author votes on the last prompt of round 1' do
      before do
        game.update!(current_prompt_index: 2) # Last prompt (index 2 of 3)
      end

      it 'advances to the next game round (writing)' do
        voter = players[1] # P1 is the voter for Prompt 2

        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, prompts.last))
        }.to change(game, :round).by(1)
         .and change(game, :status).to("writing")
      end

      it 'calculates scores at the end of the round' do
        voter = players[1]
        described_class.process_vote(game:, vote: cast_vote(voter, prompts.last))
        expect(game).to have_received(:calculate_scores!)
      end
    end

    context 'when the non-author votes on the last prompt of round 2' do
      let!(:round_2_prompts) { create_list(:prompt_instance, 3, write_and_vote_game: game, round: 2) }

      before do
        game.update!(round: 2, current_prompt_index: 2)
        round_2_prompts.each_with_index do |prompt, index|
          author1 = players[index]
          author2 = players[(index + 1) % 3]
          create(:response, prompt_instance: prompt, player: author1)
          create(:response, prompt_instance: prompt, player: author2)
        end
      end

      it 'finishes the game' do
        voter = players[1] # P1 is the voter for Prompt 2
        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, round_2_prompts.last))
        }.to change(game, :status).to("finished")
      end

      it 'calculates scores at the end of the game' do
        voter = players[1]
        described_class.process_vote(game:, vote: cast_vote(voter, round_2_prompts.last))
        expect(game).to have_received(:calculate_scores!)
      end
    end
  end

  describe 'prompt reuse' do
    let(:room) { create(:room) }
    let(:game) { create(:write_and_vote_game, room:) }

    before do
      create_list(:player, 3, room:)
      Prompt.destroy_all
      # Create exactly 6 prompts for 3 players.
      # R1 takes 3. R2 takes 3. With fix, should succeed with 0 intersection.
      create_list(:prompt, 6)
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    it 'does not reuse prompts between rounds' do
      # Round 1
      described_class.assign_prompts_for_round(game:, round_number: 1)
      round_1_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 1).pluck(:prompt_id)

      # Round 2
      described_class.assign_prompts_for_round(game:, round_number: 2)
      round_2_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 2).pluck(:prompt_id)

      # Intersection should be empty
      expect(round_1_prompt_ids & round_2_prompt_ids).to be_empty
    end
  end
end
