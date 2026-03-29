require "rails_helper"

RSpec.describe "GameFinishes", type: :request do
  describe "POST /game_finishes" do
    context "as the host player" do
      it "finishes a speed trivia game with data" do
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "answering")
        host = create(:player, room: room, name: "Host")
        room.update!(current_game: game, host: host)
        player = create(:player, room: room, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player: player, points_awarded: 500)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end

      it "resets to lobby when no scoreable data" do
        create(:trivia_pack, :default)
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "instructions")
        host = create(:player, room: room, name: "Host")
        room.update!(current_game: game, host: host)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(room.reload.status).to eq("lobby")
        expect(room.current_game).to be_nil
      end
    end

    context "as a non-host player" do
      it "rejects the request" do
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "answering")
        host = create(:player, room: room, name: "Host")
        non_host = create(:player, room: room, name: "Regular")
        room.update!(current_game: game, host: host)

        get set_player_session_path(non_host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(response).to redirect_to(room_hand_path(room))
        expect(game.reload.status).to eq("answering")
      end
    end

    context "with invalid game type" do
      it "returns not found" do
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "answering")
        host = create(:player, room: room, name: "Host")
        room.update!(current_game: game, host: host)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: "User", game_id: 1, code: room.code }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
