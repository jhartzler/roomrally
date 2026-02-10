require "rails_helper"

RSpec.describe ScoreTrackerEntry, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:room) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end
end
