require 'rails_helper'

RSpec.describe Room, type: :model do
  describe 'validations' do
    subject(:room) { create(:room) }

    it { expect(room).to validate_uniqueness_of(:code).case_insensitive }
  end

  describe 'associations' do
    it { is_expected.to have_many(:players).dependent(:destroy) }
    it { is_expected.to belong_to(:host).class_name('Player').optional }
  end

  describe 'defaults' do
    it 'defaults status to "lobby"' do
      room = described_class.new
      expect(room.status).to eq('lobby')
    end
  end

  describe 'callbacks' do
    describe '#generate_code' do
      let(:room) { described_class.new }

      it 'has a nil code before creation' do
        expect(room.code).to be_nil
      end

      it 'generates a code after creation' do
        room.save!
        expect(room.code).not_to be_nil
      end

      it 'generates a 4-letter code' do
        room.save!
        expect(room.code.length).to eq(4)
      end

      it 'generates an uppercase code' do
        room.save!
        expect(room.code).to eq(room.code.upcase)
      end

      it 'does not generate a new code on update' do
        room.save!
        original_code = room.code
        room.update(status: 'in_progress')
        expect(room.code).to eq(original_code)
      end

      # rubocop:disable RSpec/ExampleLength
      it 'retries if a code collision occurs' do
        create(:room, code: 'ABCD')

        allow(SecureRandom).to receive(:alphanumeric)
          .with(4)
          .and_return('abcd', 'wxyz')

        new_room = described_class.create!
        expect(new_room.code).to eq('WXYZ')
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end

  describe '#enough_players?' do
    let(:room) { create(:room) }

    it 'returns false when there are fewer than 3 players' do
      create_list(:player, 2, room:)
      expect(room.enough_players?).to be false
    end

    it 'returns true when there are 3 or more players' do
      create_list(:player, 3, room:)
      expect(room.enough_players?).to be true
    end
  end

  describe '#display_name' do
    let(:default_name) { described_class.default_display_name_for(Room::WRITE_AND_VOTE) }

    it 'returns the custom display_name when set' do
      room = create(:room, display_name: "Mike's Birthday Bash")
      expect(room.display_name).to eq("Mike's Birthday Bash")
    end

    it 'returns the default display name when display_name is nil' do
      room = create(:room, display_name: nil)
      expect(room.display_name).to eq(default_name)
    end

    it 'returns the default display name when display_name is blank' do
      room = create(:room, display_name: '')
      expect(room.display_name).to eq(default_name)
    end

    it 'uses GAME_DISPLAY_NAMES mapping for defaults' do
      expect(Room::GAME_DISPLAY_NAMES[Room::WRITE_AND_VOTE]).to eq(default_name)
    end
  end
end
