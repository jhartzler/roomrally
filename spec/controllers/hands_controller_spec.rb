require 'rails_helper'

RSpec.describe HandsController, type: :controller do
  describe 'GET #show' do
    let(:player) { create(:player) }

    before do
      session[:player_session_id] = player.session_id
    end

    context 'with valid room code' do
      before do
        get :show, params: { room_code: player.room.code }
      end

      it 'assigns the correct room' do
        expect(assigns(:room)).to eq(player.room)
      end

      it 'assigns the correct player' do
        expect(assigns(:player)).to eq(player)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid room code' do
      it 'redirects to root with alert' do
        get :show, params: { room_code: 'INVALID' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Room 'INVALID' not found")
      end
    end

    context 'when player has the same session_id in multiple rooms' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:shared_session_id) { SecureRandom.uuid }
      let(:room_a) { create(:room) }
      let(:room_b) { create(:room) }
      let(:player_a) { create(:player, room: room_a, session_id: shared_session_id, name: 'Alice in A') }
      let(:player_b) { create(:player, room: room_b, session_id: shared_session_id, name: 'Alice in B') }

      before do
        player_a
        player_b
        session[:player_session_id] = shared_session_id
      end

      it 'resolves to the correct player for room A' do
        get :show, params: { room_code: room_a.code }
        expect(assigns(:player)).to eq(player_a)
      end

      it 'resolves to the correct player for room B' do
        get :show, params: { room_code: room_b.code }
        expect(assigns(:player)).to eq(player_b)
      end
    end
  end
end
