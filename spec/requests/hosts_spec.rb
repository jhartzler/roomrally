require 'rails_helper'

RSpec.describe "Hosts", type: :request do
  let(:room) { FactoryBot.create(:room) }
  let(:player) { FactoryBot.create(:player, room:) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
  end

  describe "POST /rooms/:code/host" do
    context "when room has no host" do
      it "assigns the current player as host" do
        post room_host_path(room)
        expect(room.reload.host).to eq(player)
      end

      it "redirects to the hand page with success message" do
        post room_host_path(room)
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:notice]).to eq("You are now the host!")
      end
    end

    context "when room already has a host" do
      let(:other_player) { FactoryBot.create(:player, room:) }

      before { room.update!(host: other_player) }

      it "does not change the host" do
        post room_host_path(room)
        expect(room.reload.host).to eq(other_player)
      end

      it "redirects with an alert" do
        post room_host_path(room)
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to eq("There is already a host for this room.")
      end
    end
  end
end
