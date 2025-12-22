require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /auth/:provider/callback" do
    before do
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    end

    it "redirects to the dashboard on successful login" do
      get "/auth/google_oauth2/callback"
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq("Logged in successfully!")
    end
  end
end
