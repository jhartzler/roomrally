require 'rails_helper'

RSpec.describe Prompt, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:prompt_instances).dependent(:destroy) }
    it { is_expected.to belong_to(:prompt_pack).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
  end
end
