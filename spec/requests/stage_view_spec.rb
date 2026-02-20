require "rails_helper"

RSpec.describe "Stage View", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:room) { create(:room, user:, game_type: "Write And Vote") }

  describe "GET /rooms/:code/stage" do
    context "when not logged in" do
      it "redirects to root" do
        get room_stage_path(room.code)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logged in as a different user" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "redirects to root with alert" do
        get room_stage_path(room.code)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized")
      end
    end

    context "when logged in as the room owner" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "returns http success" do
        get room_stage_path(room.code)
        expect(response).to have_http_status(:success)
      end

      it "renders the room details" do
        get room_stage_path(room.code)
        expect(response.body).to include(Room.default_display_name_for(Room::WRITE_AND_VOTE))
        expect(response.body).to include(room.code)
      end

      it "displays the lobby view when game has not started" do
        get room_stage_path(room.code)
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
