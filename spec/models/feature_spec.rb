require "rails_helper"

RSpec.describe Feature, :skip_feature_seeding do
  before { Rails.cache.clear }

  describe ".sync!" do
    before { described_class.delete_all }

    it "creates missing rows disabled" do
      expect { described_class.sync! }
        .to change { described_class.pluck(:name).sort }
        .from([]).to(%w[category_list poll_game speed_trivia write_and_vote])
      expect(described_class.where(enabled: true)).to be_none
    end

    it "leaves existing enabled state alone" do
      described_class.create!(name: "speed_trivia", enabled: true)
      described_class.sync!
      expect(described_class.find("speed_trivia")).to be_enabled
      expect(described_class.where(enabled: false).count).to eq(3)
    end
  end

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

    context "when the database lookup raises" do
      it "returns false and logs the error" do
        described_class.create!(name: "write_and_vote", enabled: true)
        allow(Rails.logger).to receive(:error)
        allow(described_class).to receive(:find_by).and_raise(StandardError, "DB is down")
        expect(described_class.enabled?(:write_and_vote)).to be(false)
        expect(Rails.logger).to have_received(:error).with(/Feature flag lookup failed for write_and_vote: DB is down/)
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
