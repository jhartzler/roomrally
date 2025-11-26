require 'rails_helper'

RSpec.describe PromptInstance, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:write_and_vote_game) }
    it { is_expected.to belong_to(:prompt) }
    it { is_expected.to have_many(:responses).dependent(:destroy) }
  end
end
