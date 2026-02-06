require 'rails_helper'

RSpec.describe Player, type: :model do
  subject { build(:player) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:session_id).scoped_to(:room_id) }

    it 'validates presence of session_id' do
      player = build(:player, session_id: nil)
      expect(player).to be_valid # because the before_validation will set it
      expect(player.session_id).not_to be_nil
    end

    it 'allows the same session_id in different rooms' do
      session_id = SecureRandom.uuid
      player_a = create(:player, session_id:)
      player_b = build(:player, session_id:)

      expect(player_b).to be_valid
      expect(player_a.room).not_to eq(player_b.room)
    end

    it 'rejects duplicate session_id within the same room' do
      room = create(:room)
      existing = create(:player, room:)
      duplicate = build(:player, room:, session_id: existing.session_id)

      expect(duplicate).not_to be_valid
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

    it 'defaults status to active' do
      player = described_class.new
      expect(player.status).to eq('active')
    end
  end

  describe 'status enum' do
    it 'defines active status' do
      player = create(:player, status: :active)
      expect(player).to be_active
    end

    it 'defines pending_approval status' do
      player = create(:player, status: :pending_approval)
      expect(player).to be_pending_approval
    end
  end

  describe 'scopes' do
    let(:room) { create(:room) }
    let!(:alice) { create(:player, room:, status: :active) }
    let!(:bob) { create(:player, room:, status: :active) }
    let!(:charlie) { create(:player, room:, status: :pending_approval) }

    describe '.active_players' do
      it 'returns only active players' do
        expect(room.players.active_players).to contain_exactly(alice, bob)
      end
    end

    describe '.pending_approval' do
      it 'returns only pending approval players' do
        expect(room.players.pending_approval).to contain_exactly(charlie)
      end
    end
  end

  describe '#kick!' do
    it 'sets status to pending_approval' do
      player = create(:player, status: :active)
      player.kick!
      expect(player.reload.status).to eq('pending_approval')
    end
  end

  describe '#approve!' do
    it 'sets status to active' do
      player = create(:player, status: :pending_approval)
      player.approve!
      expect(player.reload.status).to eq('active')
    end
  end

  describe '#reject!' do
    it 'destroys the player' do
      player = create(:player, status: :pending_approval)
      expect { player.reject! }.to change(described_class, :count).by(-1)
    end
  end
end
