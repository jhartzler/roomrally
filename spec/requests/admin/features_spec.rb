require "rails_helper"

RSpec.describe "Admin::Features" do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }
  let!(:feature) { Feature.create!(name: "write_and_vote", enabled: false) }

  describe "GET /admin/features" do
    it "requires admin access" do
      sign_in(non_admin)
      get admin_features_path
      expect(response).to redirect_to(root_path)
    end

    it "renders for admin users" do
      sign_in(admin)
      get admin_features_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/features/:name/toggle" do
    it "requires admin access" do
      sign_in(non_admin)
      patch toggle_admin_feature_path(feature)
      expect(response).to redirect_to(root_path)
    end

    it "flips enabled from false to true" do
      sign_in(admin)
      expect {
        patch toggle_admin_feature_path(feature)
      }.to change { feature.reload.enabled }.from(false).to(true)
    end

    it "creates a FeatureEvent with the new state" do
      sign_in(admin)
      expect {
        patch toggle_admin_feature_path(feature)
      }.to change(FeatureEvent, :count).by(1)
      expect(FeatureEvent.last).to have_attributes(feature_name: "write_and_vote", enabled: true)
    end

    it "expires the cache entry for the feature" do
      Rails.cache.write("feature/write_and_vote", false)
      sign_in(admin)
      patch toggle_admin_feature_path(feature)
      expect(Rails.cache.read("feature/write_and_vote")).to be_nil
    end

    it "records alternating states when toggled twice" do
      sign_in(admin)
      patch toggle_admin_feature_path(feature)
      patch toggle_admin_feature_path(feature)
      events = FeatureEvent.where(feature_name: "write_and_vote").order(:created_at)
      expect(events.map(&:enabled)).to eq([true, false])
    end

    it "redirects to admin_features_path with a notice" do
      sign_in(admin)
      patch toggle_admin_feature_path(feature)
      expect(response).to redirect_to(admin_features_path)
      expect(flash[:notice]).to eq("Write and vote turned on.")
    end
  end
end
