require "rails_helper"
require "support/shared_examples/host_only_actions"

RSpec.describe "Category List host actions", type: :request do
  let(:category_pack) { create(:category_pack) }
  let(:room) { create(:room, game_type: "Category List", category_pack:) }
  let(:host_player) { create(:player, room:) }
  let(:non_host) { create(:player, room:) }

  before { room.update!(host: host_player) }

  describe "POST /category_list_games/:id/game_start (GameStartsController)" do
    let(:game) { create(:category_list_game, status: "instructions", category_pack:) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :category_list_game_game_start_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from instructions to filling" do
        post category_list_game_game_start_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("filling")
      end
    end
  end

  describe "PATCH /category_list_games/:id/review (ReviewsController) — finish review" do
    let(:game) { create(:category_list_game, status: "reviewing", category_pack:) }

    before do
      room.update!(current_game: game)
      create(:category_instance, category_list_game: game, round: 1)
      create(:category_answer, category_instance: game.category_instances.first, player: host_player, body: "Apple")
    end

    it_behaves_like "a host-only action", :category_list_game_review_path,
                    http_method: :patch

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from reviewing to scoring" do
        patch category_list_game_review_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("scoring")
      end
    end
  end

  describe "PATCH /category_list_games/:id/review_navigation (ReviewNavigationsController)" do
    let(:game) { create(:category_list_game, status: "reviewing", category_pack:, reviewing_category_position: 0) }

    before do
      room.update!(current_game: game)
      create(:category_instance, category_list_game: game, round: 1)
      create(:category_instance, category_list_game: game, round: 1)
    end

    it_behaves_like "a host-only action", :category_list_game_review_navigation_path,
                    http_method: :patch, request_params: { direction: "next" }

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "increments the reviewing category position" do
        patch category_list_game_review_navigation_path(game),
              params: { code: room.code, direction: "next" }, as: :turbo_stream

        expect(game.reload.reviewing_category_position).to eq(1)
      end
    end
  end

  describe "POST /category_list_games/:id/rounds (RoundsController) — next round" do
    let(:game) { create(:category_list_game, status: "scoring", category_pack:, current_round: 1, total_rounds: 3) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :category_list_game_rounds_path

    context "when caller is the host and rounds remain" do
      include_context "when authenticated as host"

      it "advances to the next round (scoring → filling)" do
        post category_list_game_rounds_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("filling")
        expect(game.current_round).to eq(2)
      end
    end
  end

  describe "POST /category_list_games/:id/rounds (RoundsController) — finish game" do
    let(:game) { create(:category_list_game, status: "scoring", category_pack:, current_round: 3, total_rounds: 3) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :category_list_game_rounds_path

    context "when caller is the host on the last round" do
      include_context "when authenticated as host"

      it "finishes the game" do
        post category_list_game_rounds_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("finished")
      end
    end
  end

  describe "PATCH /category_list_games/:id/stage_scores (StageScoresController)" do
    let(:game) { create(:category_list_game, status: "scoring", category_pack:, show_stage_scores: false) }

    before { room.update!(current_game: game) }

    it_behaves_like "a host-only action", :category_list_game_stage_scores_path,
                    http_method: :patch

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "toggles show_stage_scores" do
        patch category_list_game_stage_scores_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.show_stage_scores).to be true
      end
    end
  end
end
