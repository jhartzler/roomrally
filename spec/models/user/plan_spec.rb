require "rails_helper"

RSpec.describe User, "#plan", type: :model do
  describe "#pro?" do
    it "returns false by default" do
      user = create(:user)
      expect(user.pro?).to be false
    end

    it "returns false when plan is free" do
      user = create(:user, plan: "free")
      expect(user.pro?).to be false
    end

    it "returns true when plan is pro" do
      user = create(:user, plan: "pro")
      expect(user.pro?).to be true
    end
  end
end
