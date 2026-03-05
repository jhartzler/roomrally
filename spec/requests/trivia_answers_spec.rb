# spec/requests/trivia_answers_spec.rb
require "rails_helper"

RSpec.describe "TriviaAnswers", type: :request do
  describe "POST /trivia_answers (turbo_stream) — renders hand after answer" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let(:player) { create(:player, room:) }
    let(:trivia_pack) { create(:trivia_pack) }
    let(:game) do
      g = create(:speed_trivia_game, status: "answering", trivia_pack:, round_started_at: 5.seconds.ago)
      room.update!(current_game: g, trivia_pack:)
      g
    end
    let!(:question_instance) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) } # rubocop:disable RSpec/LetSetup

    before do
      get set_player_session_path(player)
    end

    it "returns 200 with hand screen content" do
      post trivia_answers_path,
           params: { trivia_answer: { selected_option: "A" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hand_screen")
    end
  end
end
