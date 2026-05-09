# frozen_string_literal: true

# Shared examples for host-only controller actions.
#
# Contract for calling spec:
#   - `game`    must be defined (the game record the action operates on)
#   - `room`    must be defined (the room the game belongs to)
#   - `host_player` must be defined (a Player who is room.host)
#   - `non_host`    must be defined (a Player in the same room, not host)
#
# Usage:
#   it_behaves_like "a host-only action", :speed_trivia_game_game_start_path
#   it_behaves_like "a host-only action", :category_list_game_game_start_path,
#                   http_method: :post
#   it_behaves_like "a host-only action", :category_list_game_review_path,
#                   http_method: :patch, request_params: { code: "ABCD" }

RSpec.shared_context "when authenticated as host" do
  before { get set_player_session_path(host_player) }
end

RSpec.shared_context "when authenticated as non-host" do
  before { get set_player_session_path(non_host) }
end

RSpec.shared_examples "a host-only action" do |path_helper, http_method: :post, request_params: {}|
  context "when caller is the host" do
    include_context "when authenticated as host"

    it "returns success" do
      params = { code: room.code }.merge(request_params)
      public_send(http_method, public_send(path_helper, game), params:, as: :turbo_stream)
      expect(response).to have_http_status(:ok)
    end
  end

  context "when caller is not the host" do
    include_context "when authenticated as non-host"

    it "redirects with an alert and does not mutate game state", :aggregate_failures do
      params = { code: room.code }.merge(request_params)
      expect {
        public_send(http_method, public_send(path_helper, game), params:, as: :turbo_stream)
      }.not_to change { game.reload.status }

      expect(response).to redirect_to(room_hand_path(room))
      expect(flash[:alert]).to eq("Only the host can control the game.")
    end
  end

  context "when caller is unauthenticated" do
    it "redirects to root with an alert" do
      params = { code: room.code }.merge(request_params)
      public_send(http_method, public_send(path_helper, game), params:, as: :turbo_stream)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized to control this game.")
    end
  end
end
