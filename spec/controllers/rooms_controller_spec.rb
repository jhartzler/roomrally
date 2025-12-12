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



  describe 'POST #claim_host' do
    let(:room) { create(:room, host: nil) }
    let(:player) { create(:player, room:) }

    before do
      session[:player_session_id] = player.session_id
    end

    context 'when there is no host' do
      it 'assigns the player as host' do
        post :claim_host, params: { code: room.code }
        room.reload
        expect(room.host).to eq(player)
      end

      it 'updates last_host_claim_at' do
        post :claim_host, params: { code: room.code }
        room.reload
        expect(room.last_host_claim_at).to be_present
      end

      it 'redirects to hand view with success notice' do
        post :claim_host, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:notice]).to eq("You are now the host!")
      end
    end

    context 'when there is already a host' do
      let(:other_player) { create(:player, room:) }

      before do
        room.update!(host: other_player)
      end

      it 'does not change the host' do
        post :claim_host, params: { code: room.code }
        room.reload
        expect(room.host).to eq(other_player)
      end

      it 'redirects with alert' do
        post :claim_host, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("There is already a host")
      end
    end

    context 'when cooloff period is active' do
      before do
        room.update!(last_host_claim_at: 15.seconds.ago)
      end

      it 'does not allow claiming host' do
        post :claim_host, params: { code: room.code }
        room.reload
        expect(room.host).to be_nil
      end

      it 'redirects with cooloff message' do
        post :claim_host, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("recently claimed")
      end
    end

    context 'when cooloff period has expired' do
      before do
        room.update!(last_host_claim_at: 31.seconds.ago)
      end

      it 'allows claiming host' do
        post :claim_host, params: { code: room.code }
        room.reload
        expect(room.host).to eq(player)
      end
    end
  end

  describe 'invalid room code handling' do
    let(:player) { create(:player) }

    before do
      session[:player_session_id] = player.session_id
    end



    it 'redirects to root with alert for POST #start_game' do
      post :start_game, params: { code: 'INVALID' }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end

    it 'redirects to root with alert for POST #claim_host' do
      post :claim_host, params: { code: 'INVALID' }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end

    it 'redirects to root with alert for POST #reassign_host' do
      post :reassign_host, params: { code: 'INVALID', player_id: 1 }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Room 'INVALID' not found")
    end
  end

  describe 'POST #start_game' do
    let(:room) { create(:room) }
    let(:host) { create(:player, room:) }

    before do
      room.update!(host:)
      session[:player_session_id] = host.session_id
      # Create some master prompts for the game to use
      3.times { |i| create(:prompt, body: "Master Prompt #{i + 1}") }
      # Create other players
      2.times { create(:player, room:) }
    end

    context 'when the current player is the host' do
      let(:listener) { instance_spy(TestListener) }

      before do
        stub_const('TestListener', Class.new { def game_started(room); end })
        allow(listener).to receive(:game_started)
        controller.subscribe(listener)
      end

      it 'updates the room status to playing' do
        post :start_game, params: { code: room.code }
        room.reload
        expect(room.status).to eq('playing')
      end

      it 'publishes the :game_started event' do
        allow(controller).to receive(:publish)
        post :start_game, params: { code: room.code }
        expect(controller).to have_received(:publish).with(:game_started, room:)
      end

      it 'redirects to the hand view' do
        post :start_game, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
      end
    end

    context 'when there are fewer than 2 players' do
      before do
        room.players.where.not(id: host.id).destroy_all
      end

      it 'does not start the game' do
        post :start_game, params: { code: room.code }
        room.reload
        expect(room.status).not_to eq('playing')
      end

      it 'redirects with an alert' do
        post :start_game, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to eq('Could not start game. Ensure there are at least 2 players and the game hasn\'t started yet.')
      end
    end

    context 'when the current player is not the host' do
      let(:other_player) { create(:player, room:) }

      before do
        session[:player_session_id] = other_player.session_id
      end

      it 'does not update the room status' do
        post :start_game, params: { code: room.code }
        room.reload
        expect(room.status).not_to eq('playing')
      end

      it 'redirects with an alert' do
        post :start_game, params: { code: room.code }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to eq('Only the host can start the game.')
      end
    end
  end

  describe 'POST #reassign_host' do
    let(:room) { create(:room) }
    let(:host_player) { create(:player, room:) }
    let(:target_player) { create(:player, room:) }

    before do
      room.update!(host: host_player)
      session[:player_session_id] = host_player.session_id
    end

    context 'when current player is the host' do
      it 'reassigns host to target player' do
        post :reassign_host, params: { code: room.code, player_id: target_player.id }
        room.reload
        expect(room.host).to eq(target_player)
      end

      it 'does not update last_host_claim_at' do
        original_claim_time = room.last_host_claim_at
        post :reassign_host, params: { code: room.code, player_id: target_player.id }
        room.reload
        expect(room.last_host_claim_at).to eq(original_claim_time)
      end

      it 'redirects with success notice' do
        post :reassign_host, params: { code: room.code, player_id: target_player.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:notice]).to include("Host has been reassigned")
      end
    end

    context 'when current player is not the host' do
      before do
        session[:player_session_id] = target_player.session_id
      end

      it 'does not change the host' do
        post :reassign_host, params: { code: room.code, player_id: host_player.id }
        room.reload
        expect(room.host).to eq(host_player)
      end

      it 'redirects with alert' do
        post :reassign_host, params: { code: room.code, player_id: host_player.id }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("Only the host can reassign")
      end
    end

    context 'when target player does not exist in room' do
      it 'redirects with alert' do
        post :reassign_host, params: { code: room.code, player_id: 99999 }
        expect(response).to redirect_to(room_hand_path(room.code))
        expect(flash[:alert]).to include("Player not found")
      end
    end
  end
end
