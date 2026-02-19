require "rails_helper"

RSpec.describe "Hand View - Speed Trivia score animation", type: :request do
  let(:room) { create(:room, game_type: "Speed Trivia") }
  let(:player) { create(:player, room:, score: 0) }

  before do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
    # rubocop:enable RSpec/AnyInstance
  end

  context "with reviewing_step 1 (answer reveal) and a player who scored points" do
    # At step 1, player.score is the pre-round cumulative total; no animation should fire.
    let(:old_score) { 500 }
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0, reviewing_step: 1)
      room.update!(current_game: g)
      g
    end

    before do
      player.update!(score: old_score)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 750, correct: true)
    end

    it "sets score_from and score_to both to the old score (no animation)" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"#{old_score}\"")
      expect(response.body).to include("data-score-tally-to-value=\"#{old_score}\"")
    end
  end

  context "with reviewing_step 2 (score reveal) and a player who scored points" do
    # At step 2, player.score is the post-round cumulative total (calculate_scores! already ran).
    # The animation should count up from old score to new score.
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0, reviewing_step: 2)
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

    it "sets score_from to old score and score_to to new score (animation plays)" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"500\"")
      expect(response.body).to include("data-score-tally-to-value=\"1250\"")
    end
  end

  context "with reviewing_step 2 and a player who scored zero points" do
    # Zero points this round: score_from == score_to so no animation fires.
    let(:score) { 500 }
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0, reviewing_step: 2)
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
