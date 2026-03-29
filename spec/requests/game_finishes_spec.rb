require "rails_helper"

RSpec.describe "GameFinishes", type: :request do
  describe "POST /game_finishes" do
    let(:room) { create(:room, game_type: "Speed Trivia", status: "playing") }
    let(:game) { create(:speed_trivia_game, status: "answering") }
    let(:host) { create(:player, room:, name: "Host") }

    before { room.update!(current_game: game, host:) }

    def end_game(game_record = game)
      post game_finishes_path, params: { game_type: game_record.class.name, game_id: game_record.id,
                                         code: room.code }
    end

    context "with scoreable speed trivia data" do
      before do
        get set_player_session_path(host)
        player = create(:player, room:, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 500)
      end

      it "finishes the game and room" do
        end_game
        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end
    end

    context "with scoreable write and vote data" do
      let(:room) { create(:room, game_type: "Write And Vote", status: "playing") }
      let(:game) { create(:write_and_vote_game, status: "voting") }

      before do
        get set_player_session_path(host)
        player = create(:player, room:, name: "Player1")
        prompt_instance = create(:prompt_instance, write_and_vote_game: game, round: 1)
        resp = create(:response, player:, prompt_instance:, body: "Funny answer")
        create(:vote, response: resp, player: host)
      end

      it "finishes the game and room" do
        end_game
        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end
    end

    context "with scoreable category list data" do
      let(:room) { create(:room, game_type: "Category List", status: "playing") }
      let(:game) { create(:category_list_game, status: "scoring") }

      before do
        get set_player_session_path(host)
        player = create(:player, room:, name: "Player1")
        ci = create(:category_instance, category_list_game: game, round: 1)
        create(:category_answer, category_instance: ci, player:, body: "Apple", points_awarded: 1)
      end

      it "finishes the game and room" do
        end_game
        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end
    end

    context "without scoreable data" do
      let(:game) { create(:speed_trivia_game, status: "instructions") }

      before do
        create(:trivia_pack, :default)
        get set_player_session_path(host)
      end

      it "resets to lobby" do
        end_game
        expect(room.reload.status).to eq("lobby")
        expect(room.current_game).to be_nil
      end
    end

    context "when a non-host player attempts to end a game" do
      let(:non_host) { create(:player, room:, name: "Regular") }

      before { get set_player_session_path(non_host) }

      it "rejects the request" do
        end_game
        expect(response).to redirect_to(room_hand_path(room))
        expect(game.reload.status).to eq("answering")
      end
    end

    context "when a backstage host ends a game" do
      let(:user) { create(:user) }
      let(:room) { create(:room, game_type: "Speed Trivia", status: "playing", user:) }

      before do
        room.update!(current_game: game)
        sign_in(user)
        player = create(:player, room:, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 500)
      end

      it "finishes the game and room" do
        end_game
        expect(game.reload.status).to eq("finished")
        expect(room.reload.status).to eq("finished")
      end
    end

    # rubocop:disable RSpec/ExampleLength
    context "when the host double-clicks end game on a finished game" do
      before do
        player = create(:player, room:, name: "Player1")
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 500)
        get set_player_session_path(host)
      end

      it "handles the second request gracefully" do
        end_game
        expect(game.reload.status).to eq("finished")

        end_game
        expect(game.reload.status).to eq("finished")
      end
    end

    context "when the host double-clicks end game on a destroyed game" do
      let(:game) { create(:speed_trivia_game, status: "instructions") }

      before do
        create(:trivia_pack, :default)
        get set_player_session_path(host)
      end

      it "returns not found on the second request" do
        game_id = game.id
        end_game
        expect(room.reload.status).to eq("lobby")

        post game_finishes_path, params: { game_type: "SpeedTriviaGame", game_id:, code: room.code }
        expect(response).to have_http_status(:not_found)
      end
    end
    # rubocop:enable RSpec/ExampleLength

    context "with an invalid game type" do
      before { get set_player_session_path(host) }

      it "returns not found" do
        post game_finishes_path, params: { game_type: "User", game_id: 1, code: room.code }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
