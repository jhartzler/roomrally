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

      it 'creates a new player' do
        expect do
          post :create, params: { code: room.code, player: player_params }
        end.to change(Player, :count).by(1)
      end

      it 'does not assign the player as host automatically' do
        post :create, params: { code: room.code, player: player_params }
        room.reload
        expect(room.host).to be_nil
      end

      it 'redirects to the hand view' do
        post :create, params: { code: room.code, player: player_params }
        expect(response).to redirect_to(room_hand_path(room))
      end

      it 'stores the session_id' do
        post :create, params: { code: room.code, player: player_params }
        expect(session[:player_session_id]).to eq(Player.last.session_id)
      end
    end

    context 'when rejoining as an active player' do
      let(:active_player) { create(:player, room:, status: :active) }

      before do
        session[:player_session_id] = active_player.session_id
      end

      it 'does not create a new player' do
        expect do
          post :create, params: { code: room.code, player: { name: 'New Name' } }
        end.not_to change(Player, :count)
      end

      it 'redirects to hand view' do
        post :create, params: { code: room.code, player: { name: 'New Name' } }
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:notice]).to include('already in this room')
      end
    end

    context 'when rejoining as a kicked player' do
      let(:kicked_player) { create(:player, room:, status: :pending_approval) }

      before do
        session[:player_session_id] = kicked_player.session_id
      end

      it 'does not create a new player' do
        expect do
          post :create, params: { code: room.code, player: { name: 'New Name' } }
        end.not_to change(Player, :count)
      end

      it 'updates the player name' do
        post :create, params: { code: room.code, player: { name: 'New Name' } }
        expect(kicked_player.reload.name).to eq('New Name')
      end

      it 'keeps status as pending_approval' do
        post :create, params: { code: room.code, player: { name: 'New Name' } }
        expect(kicked_player.reload.status).to eq('pending_approval')
      end

      it 'redirects to hand view with notice' do
        post :create, params: { code: room.code, player: { name: 'New Name' } }
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:notice]).to include('Waiting for host approval')
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

      it 'sets player status to pending_approval instead of deleting' do
        player_to_kick # ensure player exists
        expect {
          delete :destroy, params: { id: player_to_kick.id }
        }.not_to change(Player, :count)
        expect(player_to_kick.reload.status).to eq('pending_approval')
      end

      it 'redirects with success notice' do
        delete :destroy, params: { id: player_to_kick.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:notice]).to include("waiting room")
      end
    end

    context 'when room owner (user) kicks player' do
      let(:owner) { create(:user) }

      before do
        room.update!(user: owner)
        session[:user_id] = owner.id
      end

      it 'sets player status to pending_approval' do
        player_to_kick # ensure player exists
        expect {
          delete :destroy, params: { id: player_to_kick.id }
        }.not_to change(Player, :count)
        expect(player_to_kick.reload.status).to eq('pending_approval')
      end

      it 'redirects with success notice' do
        delete :destroy, params: { id: player_to_kick.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:notice]).to include("waiting room")
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
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("Only the room owner or host can perform this action")
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
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("cannot kick yourself")
      end
    end
  end

  describe 'PATCH #approve' do
    let(:room) { create(:room) }
    let(:host_player) { create(:player, room:) }
    let(:pending_player) { create(:player, room:, status: :pending_approval) }

    before do
      room.update!(host: host_player)
    end

    context 'when current player is the host' do
      before do
        session[:player_session_id] = host_player.session_id
      end

      it 'sets player status to active' do
        patch :approve, params: { id: pending_player.id }
        expect(pending_player.reload.status).to eq('active')
      end

      it 'redirects to backstage with notice' do
        patch :approve, params: { id: pending_player.id }
        expect(response).to redirect_to(room_backstage_path(room.code))
        expect(flash[:notice]).to include('approved')
      end
    end

    context 'when room owner (user) approves player' do
      let(:owner) { create(:user) }

      before do
        room.update!(user: owner)
        session[:user_id] = owner.id
      end

      it 'sets player status to active' do
        patch :approve, params: { id: pending_player.id }
        expect(pending_player.reload.status).to eq('active')
      end

      it 'redirects to backstage with notice' do
        patch :approve, params: { id: pending_player.id }
        expect(response).to redirect_to(room_backstage_path(room.code))
        expect(flash[:notice]).to include('approved')
      end
    end

    context 'when current player is not the host' do
      let(:other_player) { create(:player, room:) }

      before do
        session[:player_session_id] = other_player.session_id
      end

      it 'does not approve the player' do
        patch :approve, params: { id: pending_player.id }
        expect(pending_player.reload.status).to eq('pending_approval')
      end

      it 'redirects with alert' do
        patch :approve, params: { id: pending_player.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include('Only the room owner or host can perform this action')
      end
    end
  end

  describe 'PATCH #reject' do
    let(:room) { create(:room) }
    let(:host_player) { create(:player, room:) }
    let(:pending_player) { create(:player, room:, status: :pending_approval) }

    before do
      room.update!(host: host_player)
    end

    context 'when current player is the host' do
      before do
        session[:player_session_id] = host_player.session_id
      end

      it 'permanently deletes the player' do
        pending_player # ensure player exists
        expect {
          patch :reject, params: { id: pending_player.id }
        }.to change(Player, :count).by(-1)
      end

      it 'redirects to backstage with notice' do
        patch :reject, params: { id: pending_player.id }
        expect(response).to redirect_to(room_backstage_path(room.code))
        expect(flash[:notice]).to include('permanently removed')
      end
    end

    context 'when room owner (user) rejects player' do
      let(:owner) { create(:user) }

      before do
        room.update!(user: owner)
        session[:user_id] = owner.id
      end

      it 'permanently deletes the player' do
        pending_player # ensure player exists
        expect {
          patch :reject, params: { id: pending_player.id }
        }.to change(Player, :count).by(-1)
      end

      it 'redirects to backstage with notice' do
        patch :reject, params: { id: pending_player.id }
        expect(response).to redirect_to(room_backstage_path(room.code))
        expect(flash[:notice]).to include('permanently removed')
      end
    end

    context 'when current player is not the host' do
      let(:other_player) { create(:player, room:) }

      before do
        session[:player_session_id] = other_player.session_id
      end

      it 'does not delete the player' do
        pending_player # ensure player exists
        expect {
          patch :reject, params: { id: pending_player.id }
        }.not_to change(Player, :count)
      end

      it 'redirects with alert' do
        patch :reject, params: { id: pending_player.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include('Only the room owner or host can perform this action')
      end
    end
  end
end
