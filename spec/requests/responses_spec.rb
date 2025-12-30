require 'rails_helper'

RSpec.describe "Responses", type: :request do
  describe "PATCH /responses/:id" do
    let(:prompt_instance) { FactoryBot.create(:prompt_instance) }
    let(:game) { prompt_instance.write_and_vote_game }
    let(:room) { FactoryBot.create(:room, current_game: game) }
    let(:player) { FactoryBot.create(:player, room:) }
    let!(:player_response) { FactoryBot.create(:response, player:, prompt_instance:, body: nil) }

    before do
      # Create another player to ensure game doesn't transition to voting
      FactoryBot.create(:response, player: FactoryBot.create(:player, room:), prompt_instance:, body: nil)

      # Simulate player login
      get set_player_session_path(player)

      patch response_url(player_response), params: { response: { body: "This is a test answer." } }, as: :turbo_stream
    end

    it "returns a turbo stream media type" do
      expect(response.media_type).to eq Mime[:turbo_stream]
    end

    it "returns the correct turbo stream content" do
      expect(response.body).to include('<turbo-stream action="update"',
                                       "prompt-instance-#{prompt_instance.id}",
                                       "Your answer has been submitted!")
    end

    it "updates the response body" do
      expect(player_response.reload.body).to eq("This is a test answer.")
    end

    it "updates the prompt instance status" do
      expect(player_response.prompt_instance.reload.status).to eq("submitted")
    end
  end

  describe "IDOR attempt" do
    let!(:victim_response) { FactoryBot.create(:response, body: "Original body") }
    let(:attacker) { FactoryBot.create(:player, room: victim_response.player.room) }

    before do
      # Simulate attacker login
      get set_player_session_path(attacker)
    end

    it "prevents modifying another player's response" do
      # Attempt to update victim's response as attacker
      patch response_path(victim_response), params: { response: { body: "Malicious edit" } }, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end
end
