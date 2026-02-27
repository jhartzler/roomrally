require 'rails_helper'

RSpec.describe "Votes", type: :request do
  # Regression: VotesController called current_player.id unconditionally.
  # Without a session, current_player is nil → NoMethodError → 500.
  # Should return 401 instead.
  describe "POST /votes (unauthenticated)" do
    it "returns unauthorized instead of crashing when no player session exists" do
      post votes_path, params: { vote: { response_id: 0 } }, as: :turbo_stream

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Regression: session_id is intentionally reused across rooms (PlayersController#create
  # reuses session[:player_session_id] when it already exists). This means the same
  # session_id can appear in Player records for multiple rooms. When POST /votes has no
  # room code in params, set_current_player falls through to Player.find_by(session_id:)
  # which returns the player from the FIRST room (lowest ID) — the wrong room.
  #
  # The fix: pass code: room.code in the vote form params so set_current_player takes
  # the room-scoped lookup path.
  describe "POST /votes - player has previously joined another room (same session_id)" do
    # shared_session_id simulates a returning browser with its session cookie intact
    let(:shared_session_id) { SecureRandom.uuid }

    # old_player must be created FIRST (lower DB id) so Player.find_by(session_id:)
    # returns it rather than current_player when no room scope is provided.
    let!(:old_player) { create(:player, session_id: shared_session_id) }

    let!(:current_room) { create(:room, game_type: "Write And Vote") }
    # voteable_response: a response by another player in current_room that current_player can vote on
    let!(:voteable_response) do
      game = create(:write_and_vote_game, status: "voting", prompt_pack: create(:prompt_pack))
      current_room.update!(current_game: game)
      prompt_inst = create(:prompt_instance, write_and_vote_game: game, round: 1)
      create(:response, player: create(:player, room: current_room), prompt_instance: prompt_inst)
    end

    before do
      # current_player: the legitimate player in current_room sharing the session_id.
      # extra_player ensures required_votes = players_count - responses_count = 3 - 1 = 2,
      # so casting a single vote does NOT trigger game advancement.
      create(:player, room: current_room, session_id: shared_session_id)
      create(:player, room: current_room)
      # Simulate session as if the player is returning — the session has the shared
      # session_id, and old_player (in a different room) was the first-created match.
      get set_player_session_path(old_player)
    end

    it "casts the vote successfully when room code is passed in params" do
      expect { post votes_path, params: { vote: { response_id: voteable_response.id }, code: current_room.code }, as: :turbo_stream }
        .to change(Vote, :count).by(1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /votes (IDOR check)" do
    let(:player_a) { FactoryBot.create(:player) }
    let(:response_b) do
      prompt_pack = FactoryBot.create(:prompt_pack)
      FactoryBot.create_list(:prompt, 3, prompt_pack:)
      game = FactoryBot.create(:write_and_vote_game, prompt_pack:)
      room = FactoryBot.create(:room, current_game: game)
      prompt_inst = FactoryBot.create(:prompt_instance, write_and_vote_game: game)
      FactoryBot.create(:response, player: FactoryBot.create(:player, room:), prompt_instance: prompt_inst)
    end

    before do
      # Simulate player A login
      get set_player_session_path(player_a)
    end

    it "prevents voting for a response in another room" do
      # Attempt to vote for a response in Room B while being in Room A
      post votes_path, params: { vote: { response_id: response_b.id } }, as: :turbo_stream

      # Expect failure
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:forbidden)
    end
  end
end
