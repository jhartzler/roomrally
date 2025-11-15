require 'rails_helper'

RSpec.describe "DevTestings", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/dev/testing"
      expect(response).to have_http_status(:success)
    end
  end
end
