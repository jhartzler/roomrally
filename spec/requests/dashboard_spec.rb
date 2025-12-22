require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /dashboard" do
    context "when user is not logged in" do
      it "redirects to root path" do
        get dashboard_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Please log in.")
      end
    end

    context "when user is logged in" do
      let(:user) { create(:user, name: "Funny Creator") }

      before do
        sign_in(user)
      end

      it "returns http success" do
        get dashboard_path
        expect(response).to have_http_status(:success)
      end

      it "displays the user's name" do
        get dashboard_path
        expect(response.body).to include("Funny Creator")
      end

      it "displays quick action links" do
        get dashboard_path
        expect(response.body).to include("Manage Library")
        expect(response.body).to include("Host a Game")
      end
    end
  end
end
