require 'rails_helper'

RSpec.describe "Players", type: :request do
  let(:room) { FactoryBot.create(:room) }
  let(:join_page_event) do
    hash_including(
      event: "join_page_viewed",
      distinct_id: a_string_matching(/\Asession_.+\z/)
    )
  end
  let(:player_joined_event) do
    hash_including(
      event: "player_joined",
      properties: hash_including(player_name: "TestPlayer")
    )
  end

  describe "GET /rooms/:code/join (new)" do
    before do
      allow(Analytics).to receive(:track)
      get join_room_path(code: room.code)
    end

    it "tracks join_page_viewed with a non-empty distinct_id" do
      expect(Analytics).to have_received(:track).with(join_page_event)
    end
  end

  describe "POST /players (create)" do
    before do
      allow(Analytics).to receive(:track)
      post players_path,
           params: { player: { name: "TestPlayer" }, code: room.code }
    end

    it "tracks player_joined with player_name" do
      expect(Analytics).to have_received(:track).with(player_joined_event)
    end
  end

  describe "POST /players" do
    context "with valid params" do
      let(:player_params) { { name: "Alice" } }

      it "creates a new player" do
        expect {
          post players_path, params: { player: player_params, code: room.code }
        }.to change(Player, :count).by(1)
      end

      it "redirects to the room" do
        post players_path, params: { player: player_params, code: room.code }
        expect(response).to redirect_to(room_hand_path(room))
      end

      it "shows the player name after redirect" do
        post players_path, params: { player: player_params, code: room.code }
        follow_redirect!
        expect(response.body).to include("Alice")
      end

      it "sets the session cookie" do
        post players_path, params: { player: player_params, code: room.code }
        expect(session[:player_session_id]).to be_present
      end
    end

    context "with invalid room code" do
      let(:player_params) { { name: "Alice" } }

      it "does not create a player" do
        expect {
          post players_path, params: { player: player_params, code: "INVALID" }
        }.not_to change(Player, :count)
      end

      it "redirects to root with error" do
        post players_path, params: { player: player_params, code: "INVALID" }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Room 'INVALID' not found")
      end
    end

    context "with missing name" do
      let(:player_params) { { name: "" } }

      it "does not create a player" do
        expect {
          post players_path, params: { player: player_params, code: room.code }
        }.not_to change(Player, :count)
      end

      it "re-renders the new template with error status" do
        post players_path, params: { player: player_params, code: room.code }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
      end
    end
  end
end
