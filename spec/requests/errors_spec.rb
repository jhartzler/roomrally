require 'rails_helper'

RSpec.describe "Error Pages", type: :request do
  describe "GET /404" do
    before { get "/404" }

    it "returns the correct status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the page content" do
      expect(response.body).to include("Page Not Found")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "GET /500" do
    before { get "/500" }

    it "returns the correct status" do
      expect(response).to have_http_status(:internal_server_error)
    end

    it "renders the page content" do
      expect(response.body).to include("that wasn't supposed to happen")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "GET /422" do
    before { get "/422" }

    it "returns the correct status" do
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders the page content" do
      expect(response.body).to include("didn't go through")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "Handling unmapped routes" do
    before { get "/some/random/path/that/does/not/exist" }

    it "returns the correct status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found content" do
      expect(response.body).to include("Page Not Found")
    end
  end
end
