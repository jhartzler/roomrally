require 'rails_helper'

RSpec.describe TriviaQuestion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trivia_pack) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:correct_answer) }
    it { is_expected.to validate_presence_of(:options) }

    it 'validates options must be array of four' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: [ "A", "B", "C" ])
      expect(question).not_to be_valid
      expect(question.errors[:options]).to include("must contain exactly 4 choices")
    end

    it 'validates correct answer must be in options' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: [ "A", "B", "C", "D" ], correct_answer: "E")
      expect(question).not_to be_valid
      expect(question.errors[:correct_answer]).to include("must be one of the provided options")
    end
  end

  describe 'options' do
    it 'stores options as an array' do
      question = create(:trivia_question, options: [ "Paris", "London", "Berlin", "Madrid" ])
      expect(question.reload.options).to eq([ "Paris", "London", "Berlin", "Madrid" ])
    end
  end
end
