require "rails_helper"

RSpec.describe "GameFinishes", type: :request do
  describe "POST /game_finishes" do
    context "as the host player" do
      it "finishes a speed trivia game with data" do
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "answering")
        host = create(:player, room:, name: "Host")
        room.update!(current_game: game, host:)
        player = create(:player, room:, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 500)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end

      it "finishes a write and vote game with data" do
        room = create(:room, game_type: "Write And Vote", status: "playing")
        game = create(:write_and_vote_game, status: "voting")
        host = create(:player, room:, name: "Host")
        room.update!(current_game: game, host:)
        player = create(:player, room:, name: "Player1")
        prompt_instance = create(:prompt_instance, write_and_vote_game: game, round: 1)
        response = create(:response, player:, prompt_instance:, body: "Funny answer")
        create(:vote, response:, player: host)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end

      it "finishes a category list game with data" do
        room = create(:room, game_type: "Category List", status: "playing")
        game = create(:category_list_game, status: "scoring")
        host = create(:player, room:, name: "Host")
        room.update!(current_game: game, host:)
        player = create(:player, room:, name: "Player1")
        ci = create(:category_instance, category_list_game: game, round: 1)
        create(:category_answer, category_instance: ci, player:, body: "Apple", points_awarded: 1)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end

      it "resets to lobby when no scoreable data" do
        create(:trivia_pack, :default)
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "instructions")
        host = create(:player, room:, name: "Host")
        room.update!(current_game: game, host:)

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
        host = create(:player, room:, name: "Host")
        non_host = create(:player, room:, name: "Regular")
        room.update!(current_game: game, host:)

        get set_player_session_path(non_host)
        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(response).to redirect_to(room_hand_path(room))
        expect(game.reload.status).to eq("answering")
      end
    end

    context "as a backstage host (logged-in User)" do
      it "finishes the game" do
        user = create(:user)
        sign_in(user)
        room = create(:room, game_type: "Speed Trivia", status: "playing", user: user)
        game = create(:speed_trivia_game, status: "answering")
        room.update!(current_game: game)
        player = create(:player, room:, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 500)

        post game_finishes_path, params: { game_type: game.class.name, game_id: game.id, code: room.code }

        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end
    end

    context "with invalid game type" do
      it "returns not found" do
        room = create(:room, game_type: "Speed Trivia", status: "playing")
        game = create(:speed_trivia_game, status: "answering")
        host = create(:player, room:, name: "Host")
        room.update!(current_game: game, host:)

        get set_player_session_path(host)
        post game_finishes_path, params: { game_type: "User", game_id: 1, code: room.code }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
