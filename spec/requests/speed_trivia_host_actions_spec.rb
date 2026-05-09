require "rails_helper"

RSpec.describe "Speed Trivia host actions", type: :request do
  let(:trivia_pack) { create(:trivia_pack) }
  let(:room) { create(:room, game_type: "Speed Trivia", trivia_pack:) }
  let(:host_player) { create(:player, room:) }
  let(:non_host) { create(:player, room:) }

  before { room.update!(host: host_player) }

  shared_context "when authenticated as host" do
    before { get set_player_session_path(host_player) }
  end

  shared_context "when authenticated as non-host" do
    before { get set_player_session_path(non_host) }
  end

  shared_examples "a host-only turbo-stream action" do |path_helper|
    context "when caller is the host" do
      include_context "when authenticated as host"

      it "returns turbo-stream update targeting hand_screen", :aggregate_failures do
        post public_send(path_helper, game), as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="update"')
        expect(response.body).to include('method="morph"')
        expect(response.body).to include('target="hand_screen"')
      end
    end

    context "when caller is not the host" do
      include_context "when authenticated as non-host"

      it "redirects with an alert" do
        post public_send(path_helper, game), as: :turbo_stream

        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to eq("Only the host can control the game.")
      end
    end
  end

  describe "POST /speed_trivia_games/:id/game_start (GameStartsController)" do
    let(:game) { create(:speed_trivia_game, status: "instructions", trivia_pack:) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only turbo-stream action", :speed_trivia_game_game_start_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from instructions to waiting" do
        post speed_trivia_game_game_start_path(game), as: :turbo_stream

        expect(game.reload.status).to eq("waiting")
      end
    end
  end

  describe "POST /speed_trivia_games/:id/question (QuestionsController)" do
    let(:game) { create(:speed_trivia_game, status: "waiting", trivia_pack:) }

    before do
      room.update!(current_game: game)
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
    end

    it_behaves_like "a host-only turbo-stream action", :speed_trivia_game_question_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from waiting to answering" do
        post speed_trivia_game_question_path(game), as: :turbo_stream

        expect(game.reload.status).to eq("answering")
      end
    end
  end

  describe "POST /speed_trivia_games/:id/round_closure (RoundClosuresController)" do
    let(:game) { create(:speed_trivia_game, status: "answering", trivia_pack:) }

    before do
      room.update!(current_game: game)
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
    end

    it_behaves_like "a host-only turbo-stream action", :speed_trivia_game_round_closure_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from answering to reviewing" do
        post speed_trivia_game_round_closure_path(game), as: :turbo_stream

        expect(game.reload.status).to eq("reviewing")
      end
    end
  end

  describe "POST /speed_trivia_games/:id/advancement (AdvancementsController)" do
    let(:game) { create(:speed_trivia_game, status: "reviewing", trivia_pack:, current_question_index: 0) }

    before do
      room.update!(current_game: game)
    end

    it_behaves_like "a host-only turbo-stream action", :speed_trivia_game_advancement_path

    context "when caller is the host and questions remain" do
      include_context "when authenticated as host"

      before do
        create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_question_instance, speed_trivia_game: game, position: 1)
      end

      it "advances to the next question (reviewing → answering)" do
        post speed_trivia_game_advancement_path(game), as: :turbo_stream

        expect(game.reload.status).to eq("answering")
        expect(game.current_question_index).to eq(1)
      end
    end

    context "when caller is the host and no questions remain" do
      include_context "when authenticated as host"

      before do
        create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      end

      it "finishes the game" do
        post speed_trivia_game_advancement_path(game), as: :turbo_stream

        expect(game.reload.status).to eq("finished")
      end
    end
  end

  describe "POST /speed_trivia_games/:id/question_skip (QuestionSkipsController)" do
    let(:game) { create(:speed_trivia_game, status: "reviewing", trivia_pack:, current_question_index: 0) }

    before do
      room.update!(current_game: game)
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_question_instance, speed_trivia_game: game, position: 1)
    end

    it_behaves_like "a host-only turbo-stream action", :speed_trivia_game_question_skip_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "increments current_question_index" do
        post speed_trivia_game_question_skip_path(game), as: :turbo_stream

        expect(game.reload.current_question_index).to eq(1)
      end
    end
  end
end
