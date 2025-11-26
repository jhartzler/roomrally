# spec/services/games/write_and_vote_spec.rb
require 'rails_helper'

RSpec.describe Games::WriteAndVote do
  describe '.game_started' do
    let(:room) { create(:room) }
    let!(:player_one) { create(:player, room:) }
    let!(:player_two) { create(:player, room:) }
    let!(:player_three) { create(:player, room:) }

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
      expect(player_one.responses.count).to eq(2)
    end

    it 'assigns two prompts to player two' do
      described_class.game_started(room)
      expect(player_two.responses.count).to eq(2)
    end

    it 'assigns two prompts to player three' do
      described_class.game_started(room)
      expect(player_three.responses.count).to eq(2)
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
    end

    def cast_vote(player, prompt)
      response = prompt.responses.find_by(player:)
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
    end
  end
end
