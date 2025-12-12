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
  end
end
