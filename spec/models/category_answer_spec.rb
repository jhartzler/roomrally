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

  describe "profanity filter" do
    it "auto-rejects profane answers on save" do
      answer = create(:category_answer, body: "shit")
      expect(answer.status).to eq("rejected")
    end

    it "does not reject clean answers" do
      answer = create(:category_answer, body: "Sassy cat")
      expect(answer.status).to eq("pending")
    end
  end
end
