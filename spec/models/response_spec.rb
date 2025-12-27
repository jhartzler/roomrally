require 'rails_helper'

RSpec.describe Response, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:prompt_instance) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 'pending', submitted: 'submitted', rejected: 'rejected', published: 'published').backed_by_column_of_type(:string) }
  end

  describe 'columns' do
    it { is_expected.to have_db_column(:rejection_reason).of_type(:text) }
    it { is_expected.to have_db_column(:status).of_type(:string).with_options(default: 'pending', null: false) }
  end
end
