require "rails_helper"

RSpec.describe User, "#ai rate limiting", type: :model do
  let(:user) { create(:user) }

  def make_request(counts: true, status: :succeeded, created_at: Time.current)
    create(:ai_generation_request,
      user:,
      counts_against_limit: counts,
      status:,
      created_at:)
  end

  describe "#ai_requests_remaining" do
    it "returns 10 when no requests have been made" do
      expect(user.ai_requests_remaining).to eq(10)
    end

    it "decrements for each counting successful request in the window" do
      3.times { make_request }
      expect(user.ai_requests_remaining).to eq(7)
    end

    it "does not count non-counting requests" do
      make_request(counts: false, status: :failed)
      expect(user.ai_requests_remaining).to eq(10)
    end

    it "does not count requests older than 8 hours" do
      make_request(created_at: 9.hours.ago)
      expect(user.ai_requests_remaining).to eq(10)
    end

    it "does not go below 0" do
      11.times { make_request }
      expect(user.ai_requests_remaining).to eq(0)
    end
  end

  describe "#ai_requests_reset_at" do
    it "returns nil when no counting requests in window" do
      expect(user.ai_requests_reset_at).to be_nil
    end

    it "returns the time when the oldest request in the window will expire" do
      oldest = make_request(created_at: 3.hours.ago)
      make_request(created_at: 1.hour.ago)
      expect(user.ai_requests_reset_at).to be_within(1.second).of(oldest.created_at + 8.hours)
    end
  end

  describe "#ai_grace_failures_used" do
    it "returns 0 when no failures" do
      expect(user.ai_grace_failures_used).to eq(0)
    end

    it "counts non-counting failures in the window" do
      2.times { make_request(counts: false, status: :failed) }
      expect(user.ai_grace_failures_used).to eq(2)
    end

    it "does not count old failures" do
      make_request(counts: false, status: :failed, created_at: 9.hours.ago)
      expect(user.ai_grace_failures_used).to eq(0)
    end
  end
end
