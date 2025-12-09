require 'rails_helper'

RSpec.describe "Votes", type: :request do
  let(:game) { create(:write_and_vote_game, status: 'voting') }
  let(:room) { create(:room, current_game: game) }
  let(:player) { create(:player, room:) }
  let(:prompt_instance) { create(:prompt_instance, write_and_vote_game: game) }

  before do
    # Create master prompts for game logic to avoid running out
    create_list(:prompt, 5)
    # Simulate player login
    get set_player_session_path(player.id)
  end

  describe "POST /votes" do
    context "with valid params" do
      it "creates a new Vote" do
        other_player = create(:player, room:)
        game_response = create(:response, prompt_instance:, player: other_player)

        expect {
          post votes_path, params: { vote: { response_id: game_response.id } }
        }.to change(Vote, :count).by(1)
      end

      it "returns a turbo stream response" do
        other_player = create(:player, room:)
        game_response = create(:response, prompt_instance:, player: other_player)

        post votes_path, params: { vote: { response_id: game_response.id } }, as: :turbo_stream
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end

    context "when voting for own response" do
      it "returns forbidden status" do
        my_response = create(:response, prompt_instance:, player:)
        post votes_path, params: { vote: { response_id: my_response.id } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when voting twice for the same prompt" do
      it "returns unprocessable content status" do
        other_player = create(:player, room:)
        other_response = create(:response, prompt_instance:, player: other_player)
        create(:vote, player:, response: other_response)

        post votes_path, params: { vote: { response_id: other_response.id } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
