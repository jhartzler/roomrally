require 'rails_helper'

RSpec.describe RoomsController, type: :controller do
  describe 'POST #create' do
    it 'creates a new room' do
      expect { post :create }.to change(Room, :count).by(1)
    end

    it 'redirects to the join room path' do
      post :create
      room = Room.last
      expect(response).to redirect_to(room_stage_path(room))
    end
  end




  describe 'invalid room code handling' do
    let(:player) { create(:player) }

    before do
      session[:player_session_id] = player.session_id
    end



    it 'redirects to root with alert for invalid room' do
      get :show, params: { code: 'INVALID' }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end
  end
end
