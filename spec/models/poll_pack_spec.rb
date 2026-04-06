require "rails_helper"

RSpec.describe PollPack, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:poll_questions).dependent(:destroy) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".default" do
    it "returns a default pack when none exists" do
      pack = PollPack.default
      expect(pack).to be_a(PollPack)
    end
  end
end
