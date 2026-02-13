require 'rails_helper'

RSpec.describe TriviaQuestionInstance, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:speed_trivia_game) }
    it { is_expected.to belong_to(:trivia_question) }
    it { is_expected.to have_many(:trivia_answers) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:position) }

    it 'validates correct_answers presence' do
      instance = build(:trivia_question_instance, correct_answers: [])
      expect(instance).not_to be_valid
    end
  end
end
