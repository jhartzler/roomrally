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

  describe '#supported_players_count' do
    it 'calculates based on question count and ratio' do
      pack = create(:trivia_pack)
      create_list(:trivia_question, 10, trivia_pack: pack)
      expect(pack.supported_players_count).to eq(10)
    end
  end

  describe '#questions_per_player_ratio' do
    it 'returns 1 for trivia packs' do
      pack = create(:trivia_pack)
      expect(pack.questions_per_player_ratio).to eq(1)
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for trivia questions' do # rubocop:disable RSpec/ExampleLength
      user = create(:user)
      pack = user.trivia_packs.create!(
        name: "Test Pack",
        trivia_questions_attributes: [
          { body: "Question 1?", options: [ "A", "B", "C", "D" ], correct_answer: "A" },
          { body: "Question 2?", options: [ "W", "X", "Y", "Z" ], correct_answer: "Z" }
        ]
      )
      expect(pack.trivia_questions.count).to eq(2)
      expect(pack.trivia_questions.first.body).to eq("Question 1?")
    end
  end
end
