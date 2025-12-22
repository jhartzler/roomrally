require 'rails_helper'

RSpec.describe PromptPack, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:prompts) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:game_type) }

    context 'when game_type is Write and Vote' do
      let(:user) { create(:user) }
      let(:prompt_pack) { build(:prompt_pack, game_type: 'Write And Vote', user:) }

      it 'is not valid with fewer than 3 prompts' do
        prompt_pack.prompts = build_list(:prompt, 2)
        expect(prompt_pack).not_to be_valid
        expect(prompt_pack.errors[:base]).to include("must have at least 3 prompts for Write and Vote")
      end

      it 'is valid with 3 or more prompts' do
        prompt_pack.prompts = build_list(:prompt, 3)
        expect(prompt_pack).to be_valid
      end
    end
  end
end
