require 'rails_helper'

RSpec.describe RoomsController, type: :controller do
  describe 'POST #create' do
    it 'creates a new room' do
      expect { post :create }.to change(Room, :count).by(1)
    end

    it 'redirects to the join room path' do
      post :create
      room = Room.last
      expect(response).to redirect_to(join_room_path(room))
    end
  end

  describe 'GET #hand' do
    let(:player) { create(:player) }

    before do
      session[:player_session_id] = player.session_id
      get :hand, params: { code: player.room.code }
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
end
