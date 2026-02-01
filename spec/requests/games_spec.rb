require 'rails_helper'

RSpec.describe "Games", type: :request do
  let(:room) { FactoryBot.create(:room) }
  let(:player) { FactoryBot.create(:player, room:) }

  before do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
    # rubocop:enable RSpec/AnyInstance
  end

  describe "POST /rooms/:code/games" do
    context "when current player is host with enough players" do
      before do
        room.update!(host: player)
        FactoryBot.create_list(:player, 2, room:) # adds 2 players, total 3
        # Create enough master prompts for the game logic
        default_pack = FactoryBot.create(:prompt_pack, :default)
        FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)
      end

      it "starts the game" do
        post room_games_path(room)
        expect(room.reload.status).to eq("playing")
      end

      it "redirects with success message" do
        post room_games_path(room)
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
        post room_games_path(room)
        expect(room.reload.status).to eq("lobby")
      end

      it "redirects with error message" do
        post room_games_path(room)
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to include("Could not start game")
      end
    end

    context "when current player is NOT host" do
      let(:host) { FactoryBot.create(:player, room:) }

      before { room.update!(host:) }

      it "does not start the game" do
        post room_games_path(room)
        expect(room.reload.status).to eq("lobby")
      end

      it "redirects with error message" do
        post room_games_path(room)
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to eq("Only the host can start the game.")
      end
    end
  end
end
