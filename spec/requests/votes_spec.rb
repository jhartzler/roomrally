require 'rails_helper'

RSpec.describe "Votes", type: :request do
  describe "POST /votes (IDOR check)" do
    let(:player_a) { FactoryBot.create(:player) }
    let(:response_b) do
      prompt_pack = FactoryBot.create(:prompt_pack)
      FactoryBot.create_list(:prompt, 3, prompt_pack:)
      game = FactoryBot.create(:write_and_vote_game, prompt_pack:)
      room = FactoryBot.create(:room, current_game: game)
      prompt_inst = FactoryBot.create(:prompt_instance, write_and_vote_game: game)
      FactoryBot.create(:response, player: FactoryBot.create(:player, room:), prompt_instance: prompt_inst)
    end

    before do
      # Simulate player A login
      get set_player_session_path(player_a)
    end

    it "prevents voting for a response in another room" do
      # Attempt to vote for a response in Room B while being in Room A
      post votes_path, params: { vote: { response_id: response_b.id } }, as: :turbo_stream

      # Expect failure
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:forbidden)
    end
  end
end
