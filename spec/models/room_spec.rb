require 'rails_helper'

RSpec.describe Room, type: :model do
  describe 'validations' do
    subject(:room) { create(:room) }

    it { expect(room).to validate_uniqueness_of(:code).case_insensitive }
  end

  describe 'associations' do
    subject(:room) { described_class.new }

    it 'is expected to have many players' do
      pending('Player model does not exist yet')
      expect(room).to have_many(:players).dependent(:destroy)
    end
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
end
