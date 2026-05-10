require "rails_helper"
require "support/shared_examples/host_only_actions"

RSpec.describe "Poll host actions", type: :request do
  let(:poll_pack) { create(:poll_pack, :with_questions) }
  let(:room) { create(:room, game_type: "Poll Game", poll_pack:) }
  let(:host_player) { create(:player, room:) }
  let(:non_host) { create(:player, room:) }

  before { room.update!(host: host_player) }

  describe "POST /poll_games/:id/game_start (GameStartsController)" do
    let(:game) { create(:poll_game, status: "instructions", poll_pack:) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :poll_game_game_start_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from instructions to waiting" do
        post poll_game_game_start_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("waiting")
      end
    end
  end

  describe "POST /poll_games/:id/question (QuestionsController)" do
    let(:game) { create(:poll_game, status: "waiting", poll_pack:) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :poll_game_question_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from waiting to answering" do
        post poll_game_question_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("answering")
      end
    end
  end

  describe "POST /poll_games/:id/round_closure (RoundClosuresController)" do
    let(:game) { create(:poll_game, status: "answering", poll_pack:) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :poll_game_round_closure_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from answering to reviewing" do
        post poll_game_round_closure_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("reviewing")
      end
    end
  end

  describe "POST /poll_games/:id/advancement (AdvancementsController)" do
    let(:game) { create(:poll_game, status: "reviewing", poll_pack:, current_question_index: 0, question_count: 2) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :poll_game_advancement_path

    context "when caller is the host and questions remain" do
      include_context "when authenticated as host"

      it "advances to the next question (reviewing → answering)" do
        post poll_game_advancement_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("answering")
        expect(game.current_question_index).to eq(1)
      end
    end

    context "when caller is the host and no questions remain" do
      let(:game) { create(:poll_game, status: "reviewing", poll_pack:, current_question_index: 0, question_count: 1) }

      before do
        room.update!(current_game: game, status: "playing")
      end

      include_context "when authenticated as host"

      it "finishes the game" do
        post poll_game_advancement_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("finished")
      end
    end
  end

  describe "POST /poll_games/:id/host_answers (HostAnswersController)" do
    let(:game) { create(:poll_game, status: "reviewing", poll_pack:, scoring_mode: "host_choose", current_question_index: 0) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :poll_game_host_answers_path,
                    request_params: { answer: "dog" }

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "sets the host-chosen answer" do
        post poll_game_host_answers_path(game), params: { code: room.code, answer: "dog" }, as: :turbo_stream

        expect(game.reload.host_chosen_answer).to eq("dog")
      end
    end
  end
end
