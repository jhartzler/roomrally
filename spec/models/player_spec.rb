require 'rails_helper'

RSpec.describe Player, type: :model do
  subject { build(:player) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:session_id) }

    it 'validates presence of session_id' do
      player = build(:player, session_id: nil)
      expect(player).to be_valid # because the before_validation will set it
      expect(player.session_id).not_to be_nil
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:room) }
  end

  describe 'defaults' do
    it 'defaults score to 0' do
      player = described_class.new
      expect(player.score).to eq(0)
    end
  end
end
