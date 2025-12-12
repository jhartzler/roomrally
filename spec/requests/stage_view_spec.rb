require "rails_helper"

RSpec.describe "Stage View", type: :request do
  describe "GET /rooms/:code/stage" do
    let!(:room) { Room.create!(game_type: "Write And Vote") }

    it "returns http success" do
      get room_stage_path(room)
      expect(response).to have_http_status(:success)
    end

    it "renders the room details" do
      get room_stage_path(room)
      expect(response.body).to include("Stage View")
      expect(response.body).to include(room.code)
    end

    context "when players join" do
      it "displays the lobby view when game has not started" do
        get room_stage_path(room)
        expect(response.body).to include("Join via your phone")
        expect(response.body).to include("stage_lobby")
      end
    end

    context "when a non-existent room is accessed" do
      it "redirects to root with an alert" do
        get "/rooms/INVALID/stage"
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to include("Room 'INVALID' not found")
      end
    end
  end
end
