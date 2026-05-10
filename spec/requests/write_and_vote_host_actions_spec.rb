require "rails_helper"
require "support/shared_examples/host_only_actions"

RSpec.describe "Write And Vote host actions", type: :request do
  let(:prompt_pack) { create(:prompt_pack) }
  let(:room) { create(:room, game_type: "Write And Vote", prompt_pack:) }
  let(:host_player) { create(:player, room:) }
  let(:non_host) { create(:player, room:) }

  before { room.update!(host: host_player) }

  describe "POST /write_and_vote_games/:id/game_start (GameStartsController)" do
    let(:game) { create(:write_and_vote_game, status: "instructions", prompt_pack:) }

    before do
      room.update!(current_game: game)
      create_list(:prompt, 5, prompt_pack:)
    end

    it_behaves_like "a host-only action", :write_and_vote_game_game_start_path

    context "when caller is the host" do
      include_context "when authenticated as host"

      it "transitions the game from instructions to writing" do
        post write_and_vote_game_game_start_path(game), params: { code: room.code }, as: :turbo_stream

        expect(game.reload.status).to eq("writing")
      end
    end
  end
end
