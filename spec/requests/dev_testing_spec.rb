require 'rails_helper'

RSpec.describe "DevTesting", type: :request do
  describe "GET /dev/testing" do
    it "returns http success" do
      get "/dev/testing"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /dev/testing/create_test_game" do
    it "creates a room with players and redirects to dashboard" do
      prompt_pack = create(:prompt_pack, :default)
      6.times { create(:prompt, prompt_pack:) }

      expect {
        post "/dev/testing/create_test_game", params: { num_players: 3, game_type: "Write And Vote" }
      }.to change(Room, :count).by(1).and change(Player, :count).by(3)

      room = Room.last
      expect(room.host).to eq(room.players.first)
      expect(response).to redirect_to(show_test_game_path(room))
    end
  end

  describe "POST /dev/testing/:id/start_game" do
    it "starts a Write And Vote game" do
      prompt_pack = create(:prompt_pack, :default)
      6.times { create(:prompt, prompt_pack:) }
      room = create(:room, game_type: "Write And Vote")
      3.times { |i| create(:player, room:, name: "Player #{i + 1}") }
      room.update!(host: room.players.first)

      post "/dev/testing/#{room.code}/start_game"

      room.reload
      expect(room.status).to eq("playing")
      expect(room.current_game).to be_a(WriteAndVoteGame)
      expect(response).to redirect_to(show_test_game_path(room))
    end

    it "starts a Speed Trivia game" do
      trivia_pack = create(:trivia_pack, :default)
      5.times { create(:trivia_question, trivia_pack:) }
      room = create(:room, game_type: "Speed Trivia")
      3.times { |i| create(:player, room:, name: "Player #{i + 1}") }
      room.update!(host: room.players.first)

      post "/dev/testing/#{room.code}/start_game"

      room.reload
      expect(room.status).to eq("playing")
      expect(room.current_game).to be_a(SpeedTriviaGame)
    end
  end

  describe "POST /dev/testing/:id/advance" do
    it "advances a game from instructions" do
      prompt_pack = create(:prompt_pack, :default)
      6.times { create(:prompt, prompt_pack:) }
      room = create(:room, game_type: "Write And Vote")
      3.times { |i| create(:player, room:, name: "Player #{i + 1}") }
      room.update!(host: room.players.first)
      room.start_game!
      Games::WriteAndVote.game_started(room:, show_instructions: true)

      expect(room.current_game.status).to eq("instructions")

      post "/dev/testing/#{room.code}/advance"

      room.current_game.reload
      expect(room.current_game.status).to eq("writing")
    end
  end

  describe "POST /dev/testing/:id/bot_act" do
    it "submits bot responses during writing phase" do
      prompt_pack = create(:prompt_pack, :default)
      6.times { create(:prompt, prompt_pack:) }
      room = create(:room, game_type: "Write And Vote")
      3.times { |i| create(:player, room:, name: "Player #{i + 1}") }
      room.update!(host: room.players.first)
      room.start_game!
      Games::WriteAndVote.game_started(room:, show_instructions: false)

      expect(room.current_game.status).to eq("writing")

      post "/dev/testing/#{room.code}/bot_act"

      room.current_game.reload
      expect(room.current_game.status).to eq("voting")
    end
  end

  describe "POST /dev/testing/:id/auto_play" do
    it "does one step and redirects with auto_play params" do
      prompt_pack = create(:prompt_pack, :default)
      6.times { create(:prompt, prompt_pack:) }
      room = create(:room, game_type: "Write And Vote")
      3.times { |i| create(:player, room:, name: "Player #{i + 1}") }
      room.update!(host: room.players.first)

      post "/dev/testing/#{room.code}/auto_play", params: { auto_play: "true", interval: "2000" }

      room.reload
      expect(room.status).to eq("playing")
      expect(response).to redirect_to(show_test_game_path(room, auto_play: "true", interval: "2000"))
    end
  end
end
