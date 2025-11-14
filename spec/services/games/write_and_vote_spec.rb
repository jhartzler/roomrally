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
      3.times { |i| create(:prompt, text: "Master Prompt #{i + 1}") }
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
end
