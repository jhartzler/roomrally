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

    it 'returns false when there are fewer than 3 active players' do
      create_list(:player, 2, room:, status: :active)
      expect(room.enough_players?).to be false
    end

    it 'returns true when there are 3 or more active players' do
      create_list(:player, 3, room:, status: :active)
      expect(room.enough_players?).to be true
    end

    it 'only counts active players, not pending players' do
      create_list(:player, 2, room:, status: :active)
      create_list(:player, 5, room:, status: :pending_approval)
      expect(room.enough_players?).to be false
    end

    it 'returns true with 3 active players even if there are pending players' do
      create_list(:player, 3, room:, status: :active)
      create_list(:player, 2, room:, status: :pending_approval)
      expect(room.enough_players?).to be true
    end

    it 'returns true for game types that do not require capacity checking' do
      allow(Games::SpeedTrivia).to receive(:requires_capacity_check?).and_return(false)
      room = create(:room, game_type: Room::SPEED_TRIVIA)
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

  describe 'state transitions' do
    let(:room) { create(:room) }

    describe '#start_game!' do
      before { create_list(:player, 3, room:) }

      it 'transitions from lobby to playing' do
        expect {
          room.start_game!
        }.to change(room, :status).from('lobby').to('playing')
      end

      it 'requires at least 3 players' do
        room_with_few_players = create(:room)
        create_list(:player, 2, room: room_with_few_players)

        expect {
          room_with_few_players.start_game!
        }.not_to change(room_with_few_players, :status)
      end
    end

    describe '#finish!' do
      let(:playing_room) { create(:room, status: 'playing') }

      it 'transitions from playing to finished' do
        expect {
          playing_room.finish!
        }.to change(playing_room, :status).from('playing').to('finished')
      end

      it 'cannot finish a room in lobby state' do
        lobby_room = create(:room, status: 'lobby')

        expect {
          lobby_room.finish!
        }.not_to change(lobby_room, :status)
        expect(lobby_room.status).to eq('lobby')
      end

      it 'is idempotent for already finished rooms' do
        finished_room = create(:room, status: 'finished')

        expect {
          finished_room.finish!
        }.not_to change(finished_room, :status)
      end
    end
  end

  describe 'scopes' do
    let!(:active_lobby) { create(:room, status: 'lobby') }
    let!(:active_playing) { create(:room, status: 'playing') }
    let!(:finished_room) { create(:room, status: 'finished') }

    describe '.active' do
      it 'includes rooms in lobby state' do
        expect(described_class.active).to include(active_lobby)
      end

      it 'includes rooms in playing state' do
        expect(described_class.active).to include(active_playing)
      end

      it 'excludes finished rooms' do
        expect(described_class.active).not_to include(finished_room)
      end
    end
  end
end
