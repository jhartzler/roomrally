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
        expect(response.body).to include("Customize Games")
        expect(response.body).to include("Host a Game")
      end


      describe "game type filtering" do # rubocop:disable RSpec/NestedGroups
        before do
          create(:room, user:, created_at: 1.day.ago, game_type: "Write And Vote", code: "OLD1")
          create(:room, user:, created_at: 1.hour.ago, game_type: "Write And Vote", code: "NEW1")
          build(:room, user:, created_at: 2.hours.ago, game_type: "Other Game", code: "OTH1").save(validate: false)
        end

        it "shows only the most recent room per game type" do
          get dashboard_path

          aggregate_failures do
            expect(response.body).to include("NEW1", "OTH1")
            expect(response.body).not_to include("OLD1")
          end
        end
      end
    end
  end
end
