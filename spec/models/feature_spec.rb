require "rails_helper"

RSpec.describe Feature do
  before { Rails.cache.clear }

  describe ".enabled?" do
    context "when the feature is disabled" do
      before { described_class.create!(name: "write_and_vote", enabled: false) }

      it "returns false" do
        expect(described_class.enabled?(:write_and_vote)).to be(false)
      end
    end

    context "when the feature is enabled" do
      before { described_class.create!(name: "write_and_vote", enabled: true) }

      it "returns true" do
        expect(described_class.enabled?(:write_and_vote)).to be(true)
      end
    end

    context "when the feature row does not exist" do
      it "returns false" do
        expect(described_class.enabled?(:speed_trivia)).to be(false)
      end
    end

    context "with an unknown flag name in local env" do
      it "raises ArgumentError" do
        expect { described_class.enabled?(:totally_unknown_flag) }
          .to raise_error(ArgumentError, /Unknown feature flag: totally_unknown_flag/)
      end
    end

    context "when caching is active" do
      # Test env uses :null_store which never caches. Swap in MemoryStore
      # for this example so we can verify the cache short-circuits the DB.
      around do |example|
        # Swap in a real memory store so cache.fetch actually caches in this example
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        Rails.cache = original_cache
      end

      before { described_class.create!(name: "category_list", enabled: true) }

      it "only hits the database once across two calls" do
        Rails.cache.clear
        allow(described_class).to receive(:find_by).and_call_original
        # Warm the cache with the first call
        described_class.enabled?(:category_list)
        # Second call should be served from cache
        described_class.enabled?(:category_list)
        expect(described_class).to have_received(:find_by).once
      end
    end
  end
end
