require "rails_helper"

RSpec.describe "MobileHosts", type: :request do
  let(:room) { FactoryBot.create(:room) }

  describe "GET /rooms/:code/mobile_host" do
    it "renders the name entry form" do
      get room_mobile_host_path(room)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("name")
    end

    context "when room already has a host" do
      let(:host_player) { FactoryBot.create(:player, room:) }

      before { room.update!(host: host_player) }

      it "redirects to hand view" do
        get room_mobile_host_path(room)
        expect(response).to redirect_to(room_hand_path(room))
      end
    end

    context "when room has a facilitator" do
      let(:user) { FactoryBot.create(:user) }

      before { room.update!(user:) }

      it "redirects to join page" do
        get room_mobile_host_path(room)
        expect(response).to redirect_to(join_room_path(code: room.code))
      end
    end
  end

  describe "POST /rooms/:code/mobile_host" do
    it "creates a player, assigns as host, and redirects to hand view" do
      expect {
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      }.to change(Player, :count).by(1)

      player = Player.last
      expect(player.name).to eq("Alex")
      expect(player.status).to eq("active")
      expect(player.room).to eq(room)
      expect(room.reload.host).to eq(player)
      expect(response).to redirect_to(room_hand_path(room))
    end

    it "sets the session player_session_id" do
      post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    context "when session already has a player in this room" do
      before do
        # First POST creates a player and sets the session
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      end

      it "redirects to hand view without creating a new player" do
        expect {
          post room_mobile_host_path(room), params: { player: { name: "Bob" } }
        }.not_to change(Player, :count)
        expect(response).to redirect_to(room_hand_path(room))
      end
    end

    context "when room already has a host" do
      let(:host_player) { FactoryBot.create(:player, room:) }

      before { room.update!(host: host_player) }

      it "redirects to hand view with alert" do
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to be_present
      end
    end

    context "when room has a facilitator" do
      let(:user) { FactoryBot.create(:user) }

      before { room.update!(user:) }

      it "redirects to join page" do
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
        expect(response).to redirect_to(join_room_path(code: room.code))
      end
    end

    context "when player name is blank" do
      it "re-renders the form with errors" do
        post room_mobile_host_path(room), params: { player: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
