require 'rails_helper'

RSpec.describe "Rooms", type: :request do
  let(:room) { FactoryBot.create(:room) }
  let(:player) { FactoryBot.create(:player, room:) }

  # Helper to simulate login
  before do
    # We need to set the session manually or use a helper if available.
    # Since we don't have a login helper for request specs yet, we can simulate it
    # by mocking the current_player method or by setting the session directly if possible.
    # Rails request specs allow accessing session but setting it directly can be tricky depending on config.
    # A better way is to use `allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)`
    # or just stub the method on the controller instance if we could access it, but we can't easily in request specs.
    # Let's try stubbing ApplicationController#current_player for now as it's the simplest way in RSpec without a helper.
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
    # rubocop:enable RSpec/AnyInstance
  end

  describe "POST /rooms/:code/claim_host" do
    context "when room has no host" do
      it "assigns the current player as host" do
        post claim_host_room_path(room)
        expect(room.reload.host).to eq(player)
      end

      it "redirects to the hand page with success message" do
        post claim_host_room_path(room)
        expect(response).to redirect_to(hand_room_path(room))
        expect(flash[:notice]).to eq("You are now the host!")
      end
    end

    context "when room already has a host" do
      let(:other_player) { FactoryBot.create(:player, room:) }

      before { room.update!(host: other_player) }

      it "does not change the host" do
        post claim_host_room_path(room)
        expect(room.reload.host).to eq(other_player)
      end

      it "redirects with an alert" do
        post claim_host_room_path(room)
        expect(response).to redirect_to(hand_room_path(room))
        expect(flash[:alert]).to eq("There is already a host for this room.")
      end
    end
  end

  describe "POST /rooms/:code/start_game" do
    context "when current player is host with enough players" do
      before do
        room.update!(host: player)
        FactoryBot.create_list(:player, 2, room:) # adds 2 players, total 3
        # Create enough master prompts for the game logic
        FactoryBot.create_list(:prompt, 5)
      end

      it "starts the game" do
        post start_game_room_path(room)
        expect(room.reload.status).to eq("playing")
      end

      it "redirects with success message" do
        post start_game_room_path(room)
        expect(response).to redirect_to(hand_room_path(room))
        expect(flash[:notice]).to eq("Game started!")
      end
    end

    context "when current player is host without enough players" do
      before do
        room.update!(host: player)
        FactoryBot.create(:player, room:) # Total 2 players (not enough)
      end

      it "does not start the game" do
        post start_game_room_path(room)
        expect(room.reload.status).to eq("lobby")
      end

      it "redirects with error message" do
        post start_game_room_path(room)
        expect(response).to redirect_to(hand_room_path(room))
        expect(flash[:alert]).to include("Could not start game")
      end
    end

    context "when current player is NOT host" do
      let(:host) { FactoryBot.create(:player, room:) }

      before { room.update!(host:) }

      it "does not start the game" do
        post start_game_room_path(room)
        expect(room.reload.status).to eq("lobby")
      end

      it "redirects with error message" do
        post start_game_room_path(room)
        expect(response).to redirect_to(hand_room_path(room))
        expect(flash[:alert]).to eq("Only the host can start the game.")
      end
    end
  end
end
