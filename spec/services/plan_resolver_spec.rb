require "rails_helper"

RSpec.describe PlanResolver do
  describe ".for" do
    it "returns a PlanResolver instance" do
      expect(described_class.for(nil)).to be_a(PlanResolver)
    end

    it "returns free tier for nil user" do
      resolver = described_class.for(nil)
      expect(resolver.tier).to eq(:free)
    end

    it "returns free tier for any user (without engine)" do
      user = create(:user)
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:free)
    end
  end

  describe "#limits" do
    let(:resolver) { described_class.for(nil) }

    it "returns free-tier AI request limit" do
      expect(resolver.limits[:ai_requests_per_window]).to eq(10)
    end

    it "returns free-tier AI grace failure limit" do
      expect(resolver.limits[:ai_grace_failures]).to eq(3)
    end

    it "returns free-tier audience size" do
      expect(resolver.limits[:audience_size]).to eq(10)
    end

    it "returns free-tier pack image limit" do
      expect(resolver.limits[:pack_image_limit]).to eq(20)
    end
  end

  describe "#within_limit?" do
    let(:resolver) { described_class.for(nil) }

    it "returns true when value is within limit" do
      expect(resolver.within_limit?(:audience_size, 5)).to be true
    end

    it "returns true when value equals limit" do
      expect(resolver.within_limit?(:audience_size, 10)).to be true
    end

    it "returns false when value exceeds limit" do
      expect(resolver.within_limit?(:audience_size, 11)).to be false
    end
  end

  describe "#pro?" do
    it "returns false for free tier" do
      expect(described_class.for(nil).pro?).to be false
    end
  end
end
