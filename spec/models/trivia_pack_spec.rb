require 'rails_helper'

RSpec.describe TriviaPack, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:trivia_questions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, live: 1) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:global_pack) { create(:trivia_pack, :global) }
    let!(:user_pack) { create(:trivia_pack, user:) }

    describe '.global' do
      it 'returns packs without a user' do
        expect(described_class.global).to include(global_pack)
        expect(described_class.global).not_to include(user_pack)
      end
    end

    describe '.accessible_by' do
      it 'returns global packs and user-owned packs' do
        accessible = described_class.accessible_by(user)
        expect(accessible).to include(global_pack, user_pack)
      end
    end
  end

  describe '.default' do
    it 'returns the pack marked as default' do
      create(:trivia_pack, :global)
      default_pack = create(:trivia_pack, :default)
      expect(described_class.default).to eq(default_pack)
    end

    it 'falls back to first global pack if no default' do
      global_pack = create(:trivia_pack, :global)
      expect(described_class.default).to eq(global_pack)
    end
  end
end
