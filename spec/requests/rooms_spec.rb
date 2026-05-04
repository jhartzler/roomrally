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
        expect(response).to redirect_to(room_hand_path(room))
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
        expect(response).to redirect_to(room_hand_path(room))
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
        default_pack = FactoryBot.create(:prompt_pack, :default)
        FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)
      end

      it "starts the game" do
        post start_game_room_path(room)
        expect(room.reload.status).to eq("playing")
      end

      it "redirects with success message" do
        post start_game_room_path(room)
        expect(response).to redirect_to(room_hand_path(room))
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
        expect(response).to redirect_to(room_hand_path(room))
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
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to eq("Only the host can start the game.")
      end
    end
  end

  describe "POST /rooms (create)" do
    let(:game_type) { "Write And Vote" }

    # Override the outer before block — create specs test unauthenticated guests
    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(nil)
      # rubocop:enable RSpec/AnyInstance
    end

    context "when guest user on desktop" do
      it "redirects to stage view" do
        post rooms_path, params: { game_type: }
        room = Room.last
        expect(response).to redirect_to(room_stage_path(room))
      end
    end

    context "when guest user on mobile" do
      it "redirects to mobile host setup" do
        post rooms_path, params: { game_type: },
             headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148" }
        room = Room.last
        expect(response).to redirect_to(room_mobile_host_path(room))
      end
    end

    context "when logged-in user" do
      let(:user) { FactoryBot.create(:user) }

      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "redirects to backstage regardless of UA" do
        post rooms_path, params: { game_type: },
             headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148" }
        room = Room.last
        expect(response).to redirect_to(room_backstage_path(room))
      end
    end

    context "when a game type is disabled" do
      before do
        Feature.sync!
        Feature::FEATURES.each { |name| Feature.find(name.to_s).update!(enabled: true) }
        Feature.find("speed_trivia").update!(enabled: false)
        Rails.cache.clear
      end

      it "rejects the disabled game type" do
        post rooms_path, params: { game_type: "Speed Trivia" }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
