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

  describe "GET /" do
    before { get root_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays all three game mode tiles" do
      aggregate_failures do
        expect(response.body).to include("Comedy Clash")
        expect(response.body).to include("A-List")
        expect(response.body).to include("Think Fast")
      end
    end

    it "displays the How It Works section with four steps" do
      aggregate_failures do
        expect(response.body).to include("How It Works")
        expect(response.body).to include("Pick Your Game Mode")
        expect(response.body).to include("Make It Yours")
        expect(response.body).to include("Launch &amp; Display")
        expect(response.body).to include("Everyone Joins")
      end
    end
  end
end
