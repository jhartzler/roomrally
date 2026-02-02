require 'rails_helper'

RSpec.describe "Pages", type: :request do
  describe "GET /privacy" do
    it "returns http success" do
      get privacy_path
      expect(response).to have_http_status(:success)
    end

    it "displays the privacy policy content" do
      get privacy_path
      expect(response.body).to include("Privacy Policy")
      expect(response.body).to include("We Will Never Sell Your Data")
    end
  end

  describe "GET /terms" do
    it "returns http success" do
      get terms_path
      expect(response).to have_http_status(:success)
    end

    it "displays the terms of service content" do
      get terms_path
      expect(response.body).to include("Terms of Service")
      expect(response.body).to include("Alpha Status Disclaimer")
    end
  end
end
