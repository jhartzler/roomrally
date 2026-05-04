require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      head :ok
    end
  end

  describe "Sentry context" do
    let(:user) { create(:user) }
    let(:room) { create(:room) }
    let(:player) { create(:player, room:) }

    before do
      allow(Sentry).to receive(:set_user)
      allow(Sentry).to receive(:set_tags)
      allow(Sentry).to receive(:set_context)
    end

    context "when user is signed in" do
      before do
        session[:user_id] = user.id
        get :index
      end

      it "sets the Sentry user context" do
        expect(Sentry).to have_received(:set_user).with(id: user.id)
      end
    end

    context "when player session exists" do
      before do
        session[:player_session_id] = player.session_id
        get :index, params: { code: room.code }
      end

      it "sets the player_id tag" do
        expect(Sentry).to have_received(:set_tags).with(player_id: player.id)
      end

      it "sets the room_code tag from the player's room" do
        expect(Sentry).to have_received(:set_tags).with(room_code: room.code)
      end

      it "sets the room context" do
        expect(Sentry).to have_received(:set_context).with("room", { code: room.code })
      end
    end

    context "when room code is provided in params" do
      let(:room_code) { "TEST" }

      before do
        get :index, params: { code: room_code }
      end

      it "sets the room_code tag" do
        expect(Sentry).to have_received(:set_tags).with(room_code:)
      end

      it "sets the room context" do
        expect(Sentry).to have_received(:set_context).with("room", { code: room_code })
      end
    end
  end
end
