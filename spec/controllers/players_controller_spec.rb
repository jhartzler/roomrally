require 'rails_helper'

RSpec.describe PlayersController, type: :controller do
  let(:room) { create(:room) }

  describe 'GET #new' do
    before { get :new, params: { code: room.code } }

    it 'assigns the correct room' do
      expect(assigns(:room)).to eq(room)
    end

    it 'assigns a new player' do
      expect(assigns(:player)).to be_a_new(Player)
    end

    it 'returns a successful response' do
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      let(:player_params) { { name: 'Reynard' } }

      before { post :create, params: { code: room.code, player: player_params } }

      it 'creates a new player' do
        expect do
          post :create, params: { code: room.code, player: player_params }
        end.to change(Player, :count).by(1)
      end


      it 'assigns the player as host if they are the first to join' do
        room.reload
        expect(room.host).to eq(Player.last)
      end

      it 'redirects to the hand view' do
        expect(response).to redirect_to(hand_room_path(room))
      end

      it 'stores the session_id' do
        expect(session[:player_session_id]).to eq(Player.last.session_id)
      end
    end

    context 'with invalid params' do
      let(:player_params) { { name: '' } }

      before { post :create, params: { code: room.code, player: player_params } }

      it 'does not create a new player' do
        expect do
          post :create, params: { code: room.code, player: player_params }
        end.not_to change(Player, :count)
      end


      it 're-renders the new template' do
        expect(response).to render_template(:new)
      end

      it 'returns an unprocessable content status' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
