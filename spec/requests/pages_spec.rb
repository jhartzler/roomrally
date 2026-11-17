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
    # PARKED: root now redirects to the static parked page (public/parked.html)
    it "redirects to the parked page" do
      get root_path
      expect(response).to redirect_to("/parked.html")
    end
  end

  describe "GET /parked.html" do
    before { get "/parked.html" }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "explains the app is paused" do
      expect(response.body).to include("paused")
    end

    it "describes all four game modes" do
      aggregate_failures do
        expect(response.body).to include("Comedy Clash")
        expect(response.body).to include("A-List")
        expect(response.body).to include("Think Fast")
        expect(response.body).to include("Bandwagon")
      end
    end

    it "links to the contact Google form" do
      expect(response.body).to include("https://forms.gle/xyHntsW9Kku1yaBw6")
    end
  end

  describe "unmatched routes" do
    it "redirects to the parked page (including old room codes)" do
      get "/ABCD"
      expect(response).to redirect_to("/parked.html")

      get "/some/old/path"
      expect(response).to redirect_to("/parked.html")
    end
  end
end
