require 'rails_helper'

RSpec.describe "Backstages", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:room) { create(:room, user:) }

  describe "GET /rooms/:code/backstage" do
    context "when not logged in" do
      it "redirects to root" do
        get room_backstage_path(room.code)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logged in as a different user" do
      before do
        # Simulate login (assuming ApplicationController helper or similar mechanism)
        # Using a mock or depending on how current_user is set in request specs.
        # Since I see 'current_user' in Controllers, I'll assume standard session or helper.
        # If no direct helper, I might need to look at how other request specs do it.
        # For now, simplistic approach:
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)
      end

      it "redirects to root with alert" do
        get room_backstage_path(room.code)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized")
      end
    end

    context "when logged in as the room owner" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      end

      it "returns http success and displays room info" do
        create(:player, room:, name: "Alice")
        get room_backstage_path(room.code)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(room.code)
        expect(response.body).to include("Alice")
      end
    end
  end
end
