require 'rails_helper'

RSpec.describe "Responses", type: :request do
  describe "PATCH /responses/:id" do
    let(:game) { create(:write_and_vote_game, status: "writing") }
    let(:room) { create(:room, current_game: game, game_type: "Write And Vote") }
    let(:player) { create(:player, room:) }
    let(:prompt_instance) { create(:prompt_instance, write_and_vote_game: game) }
    let!(:player_response) { create(:response, player:, prompt_instance:, body: nil) }

    before do
      # Create another player and response to ensure game doesn't transition to voting
      other_player = create(:player, room:)
      create(:response, player: other_player, prompt_instance:, body: nil)

      get set_player_session_path(player)
    end

    it "returns turbo-stream update targeting hand_screen", :aggregate_failures do
      patch response_url(player_response), params: { response: { body: "This is a test answer." } }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('method="morph"')
      expect(response.body).to include('target="hand_screen"')
    end

    it "updates the response body" do
      patch response_url(player_response), params: { response: { body: "This is a test answer." } }, as: :turbo_stream

      expect(player_response.reload.body).to eq("This is a test answer.")
    end

    it "updates the prompt instance status" do
      patch response_url(player_response), params: { response: { body: "This is a test answer." } }, as: :turbo_stream

      expect(player_response.prompt_instance.reload.status).to eq("submitted")
    end

    it "auto-rejects profane responses" do
      patch response_url(player_response), params: { response: { body: "what the shit" } }, as: :turbo_stream

      expect(player_response.reload.status).to eq("rejected")
    end

    it "does not reject clean responses" do
      patch response_url(player_response), params: { response: { body: "a classy answer" } }, as: :turbo_stream

      expect(player_response.reload.status).to eq("submitted")
    end
  end
end
