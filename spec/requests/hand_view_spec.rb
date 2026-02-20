require "rails_helper"

RSpec.describe "Hand View - Speed Trivia score animation", type: :request do
  let(:room) { create(:room, game_type: "Speed Trivia") }
  let(:player) { create(:player, room:, score: 0) }

  before do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
    # rubocop:enable RSpec/AnyInstance
  end

  context "when reviewing and the player scored points this round" do
    # player.score is already the post-round total (calculate_scores! runs in close_round).
    # The animation counts from old score to new score.
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0)
      room.update!(current_game: g)
      g
    end

    before do
      round_points = 750
      old_score = 500
      player.update!(score: old_score + round_points)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: round_points, correct: true)
    end

    it "animates from old score to new score" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"500\"")
      expect(response.body).to include("data-score-tally-to-value=\"1250\"")
    end
  end

  context "when reviewing and the player scored zero points this round" do
    # score_from == score_to so no animation fires.
    let(:score) { 500 }
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0)
      room.update!(current_game: g)
      g
    end

    before do
      player.update!(score:)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 0, correct: false)
    end

    it "sets score_from and score_to both to the same value (no animation)" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"#{score}\"")
      expect(response.body).to include("data-score-tally-to-value=\"#{score}\"")
    end
  end
end
