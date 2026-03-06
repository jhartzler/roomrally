require "rails_helper"

RSpec.describe PlanResolver, "with pro engine" do
  describe ".for" do
    it "returns pro tier for pro user" do
      user = create(:user, plan: "pro")
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:pro)
    end

    it "returns free tier for free user" do
      user = create(:user, plan: "free")
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:free)
    end

    it "returns free tier for nil user" do
      resolver = described_class.for(nil)
      expect(resolver.tier).to eq(:free)
    end
  end

  describe "#limits for pro user" do
    let(:resolver) { described_class.for(create(:user, plan: "pro")) }

    it "returns pro audience size" do
      expect(resolver.limits[:audience_size]).to eq(50)
    end

    it "returns pro AI request limit" do
      expect(resolver.limits[:ai_requests_per_window]).to eq(50)
    end

    it "returns pro AI grace failure limit" do
      expect(resolver.limits[:ai_grace_failures]).to eq(10)
    end

    it "returns pro pack image limit" do
      expect(resolver.limits[:pack_image_limit]).to eq(50)
    end
  end

  describe "#pro?" do
    it "returns true for pro user" do
      user = create(:user, plan: "pro")
      expect(described_class.for(user).pro?).to be true
    end

    it "returns false for free user" do
      user = create(:user, plan: "free")
      expect(described_class.for(user).pro?).to be false
    end
  end

  describe "integration: User#ai_request_limit respects plan" do
    it "returns 10 for free user" do
      user = create(:user, plan: "free")
      expect(user.ai_request_limit).to eq(10)
    end

    it "returns 50 for pro user" do
      user = create(:user, plan: "pro")
      expect(user.ai_request_limit).to eq(50)
    end
  end
end
