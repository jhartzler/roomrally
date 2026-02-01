require 'rails_helper'

RSpec.describe TriviaQuestion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trivia_pack) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:correct_answer) }
  end

  describe 'options' do
    it 'stores options as an array' do
      question = create(:trivia_question, options: [ "Paris", "London", "Berlin", "Madrid" ])
      expect(question.reload.options).to eq([ "Paris", "London", "Berlin", "Madrid" ])
    end
  end
end
