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
        expect(response.body).to include("New Game")
        expect(response.body).to include("Quick Host")
      end

      context "when a game type is disabled" do # rubocop:disable RSpec/NestedGroups
        before do
          Feature.find("speed_trivia").update!(enabled: false)
          Rails.cache.clear
        end

        it "hides the disabled game type from the New Game section" do
          get dashboard_path
          expect(response.body).not_to include("Think Fast")
        end

        it "still shows enabled game types" do
          get dashboard_path
          expect(response.body).to include("Comedy Clash")
          expect(response.body).to include("A-List")
        end
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
            expect(response.body).to include("NEW1")
            expect(response.body).not_to include("OLD1")
          end
        end
      end
    end
  end
end
