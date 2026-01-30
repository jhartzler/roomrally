require 'rails_helper'

RSpec.describe "Error Pages", type: :request do
  describe "GET /404" do
    it "returns the custom 404 page with correct status" do
      get "/404"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page Not Found")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "GET /500" do
    it "returns the custom 500 page with correct status" do
      get "/500"
      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("Something Went Wrong")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "GET /422" do
    it "returns the custom 422 page with correct status" do
      get "/422"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Change Rejected")
      expect(response.body).to include("Return to Lobby")
    end
  end

  describe "Handling unmapped routes" do
    it "routes random paths to the 404 page" do
      get "/some/random/path/that/does/not/exist"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page Not Found")
    end
  end
end
