require "rails_helper"

RSpec.describe CategoryAnswer, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:category_instance) }
  end

  describe "validations" do
    subject { create(:category_answer) }

    it { is_expected.to validate_uniqueness_of(:player_id).scoped_to(:category_instance_id) }
  end
end
