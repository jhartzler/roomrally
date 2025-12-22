require 'rails_helper'

RSpec.describe PromptPack, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:prompts) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:game_type) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, live: 1) }
  end

  describe '#supported_players_count' do
    let(:user) { create(:user) }
    let(:prompt_pack) { create(:prompt_pack, game_type: 'Write And Vote', user:) }

    context 'when game_type is Write And Vote' do
      it 'returns the number of prompts' do
        create_list(:prompt, 5, prompt_pack:)
        expect(prompt_pack.supported_players_count).to eq(5)
      end
    end
  end
end
