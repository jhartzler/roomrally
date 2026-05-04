require "rails_helper"

RSpec.describe FeatureEvent, :skip_feature_seeding do
  describe "readonly after creation" do
    it "raises ActiveRecord::ReadOnlyRecord when updating after save" do
      feature = Feature.create!(name: "write_and_vote", enabled: false)
      event = described_class.create!(feature_name: feature.name, enabled: false, created_at: Time.current)
      expect { event.update!(enabled: true) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "validations" do
    it "requires feature_name" do
      event = described_class.new(feature_name: nil, enabled: false, created_at: Time.current)
      expect(event).not_to be_valid
      expect(event.errors[:feature]).to be_present
    end

    it "validates enabled is a boolean" do
      feature = Feature.create!(name: "write_and_vote", enabled: false)
      event = described_class.new(feature_name: feature.name, enabled: nil)
      expect(event).not_to be_valid
      expect(event.errors[:enabled]).to be_present
    end
  end
end
