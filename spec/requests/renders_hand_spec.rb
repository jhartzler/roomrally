# spec/requests/renders_hand_spec.rb
require "rails_helper"

# Regression: after the turbo-frame migration, game action controllers return
# the hand partial in the HTTP response (200 + turbo-stream update) rather than
# 204 no-content. This ensures the submitting player's hand updates from HTTP,
# not just from the WebSocket broadcast.
RSpec.describe "RendersHand concern — HTTP response updates hand", type: :request do
  describe "Speed Trivia: POST /trivia_answers" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let(:player) { create(:player, room:) }
    let(:trivia_pack) { create(:trivia_pack) }
    let(:game) do
      g = create(:speed_trivia_game, status: "answering", trivia_pack:, round_started_at: 5.seconds.ago)
      room.update!(current_game: g, trivia_pack:)
      g
    end
    let!(:question_instance) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) } # rubocop:disable RSpec/LetSetup

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      post trivia_answers_path,
           params: { trivia_answer: { selected_option: "A" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end

  describe "Write & Vote: POST /votes" do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:room) { create(:room, game_type: "Write And Vote") }
    let(:player) { create(:player, room:) }
    let(:other_player) { create(:player, room:) }
    # extra_player raises required_votes to 3 - 1 = 2 so one vote does not trigger advancement
    let!(:extra_player) { create(:player, room:) } # rubocop:disable RSpec/LetSetup
    let(:prompt_pack) { create(:prompt_pack) }
    let(:game) do
      g = create(:write_and_vote_game, status: "voting", prompt_pack:)
      room.update!(current_game: g)
      g
    end
    let(:prompt_instance) { create(:prompt_instance, write_and_vote_game: game, round: 1) }
    let!(:voteable_response) { create(:response, player: other_player, prompt_instance:) } # rubocop:disable RSpec/LetSetup

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      post votes_path,
           params: { vote: { response_id: voteable_response.id }, code: room.code },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end

  describe "Category List: POST submissions" do
    let(:room) { create(:room, game_type: "Category List") }
    let(:player) { create(:player, room:) }
    # extra_player prevents all_answers_submitted? from triggering after one submission
    let!(:extra_player) { create(:player, room:) } # rubocop:disable RSpec/LetSetup
    let(:game) do
      g = create(:category_list_game, status: "filling")
      room.update!(current_game: g)
      g
    end
    # category_instance provides a valid answers key; params.require(:answers) raises on empty hash
    let!(:category_instance) { create(:category_instance, category_list_game: game, round: 1) } # rubocop:disable RSpec/LetSetup

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      post category_list_game_submissions_path(game),
           params: { answers: { category_instance.id.to_s => "Aardvark" }, code: room.code },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end
end
