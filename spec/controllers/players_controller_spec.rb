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


      it 'does not assign the player as host automatically' do
        room.reload
        expect(room.host).to be_nil
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

  describe 'invalid room code handling' do
    it 'redirects to root with alert for GET #new' do
      get :new, params: { code: 'INVALID' }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end

    it 'redirects to root with alert for POST #create' do
      post :create, params: { code: 'INVALID', player: { name: 'Test' } }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end
  end

  describe 'DELETE #destroy' do
    let(:room) { create(:room) }
    let(:host_player) { create(:player, room:) }
    let(:player_to_kick) { create(:player, room:) }

    before do
      room.update!(host: host_player)
    end

    context 'when current player is the host' do
      before do
        session[:player_session_id] = host_player.session_id
      end

      it 'deletes the player' do
        player_to_kick # ensure player exists
        expect {
          delete :destroy, params: { id: player_to_kick.id }
        }.to change(Player, :count).by(-1)
      end

      it 'redirects with success notice' do
        delete :destroy, params: { id: player_to_kick.id }
        expect(response).to redirect_to(hand_room_path(room.code))
        expect(flash[:notice]).to include("has been kicked")
      end
    end

    context 'when current player is not the host' do
      before do
        session[:player_session_id] = player_to_kick.session_id
      end

      it 'does not delete the player' do
        host_player # ensure both players exist
        player_to_kick
        expect {
          delete :destroy, params: { id: host_player.id }
        }.not_to change(Player, :count)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: host_player.id }
        expect(response).to redirect_to(hand_room_path(room.code))
        expect(flash[:alert]).to include("Only the host can kick")
      end
    end

    context 'when host tries to kick themselves' do
      before do
        session[:player_session_id] = host_player.session_id
      end

      it 'does not delete the host' do
        expect {
          delete :destroy, params: { id: host_player.id }
        }.not_to change(Player, :count)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: host_player.id }
        expect(response).to redirect_to(hand_room_path(room.code))
        expect(flash[:alert]).to include("cannot kick yourself")
      end
    end
  end
end
