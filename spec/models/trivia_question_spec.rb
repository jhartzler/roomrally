require 'rails_helper'

RSpec.describe TriviaQuestion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trivia_pack) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:options) }

    it 'validates options must be array of four' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C"])
      expect(question).not_to be_valid
      expect(question.errors[:options]).to include("must contain exactly 4 choices")
    end

    it 'validates correct_answers must be present' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: [])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must have at least one correct answer")
    end

    it 'validates correct_answers must be an array' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: "Paris")
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must be an array")
    end

    it 'validates all correct_answers must be in options' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"], correct_answers: ["E"])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must all be included in options")
    end

    it 'allows multiple correct answers' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"], correct_answers: ["A", "B"])
      expect(question).to be_valid
    end
  end

  describe 'options' do
    it 'stores options as an array' do
      question = create(:trivia_question, options: ["Paris", "London", "Berlin", "Madrid"])
      expect(question.reload.options).to eq(["Paris", "London", "Berlin", "Madrid"])
    end
  end
end
