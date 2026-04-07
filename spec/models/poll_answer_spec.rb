require "rails_helper"

RSpec.describe PollAnswer, type: :model do
  describe "#calculate_points" do
    let(:game) { create(:poll_game) }
    let(:question) { create(:poll_question, poll_pack: game.poll_pack, options: [ "a", "b" ]) }
    let(:player) { create(:player) }

    it "returns MAXIMUM_POINTS for an instant answer" do
      answer = build(:poll_answer, poll_game: game, poll_question: question, player:)
      round_started_at = 10.seconds.ago
      round_closed_at = Time.current
      answer.submitted_at = round_started_at
      expect(answer.calculate_points(round_started_at:, round_closed_at:)).to eq(PollGame::MAXIMUM_POINTS)
    end

    it "returns MINIMUM_POINTS for a late answer" do
      answer = build(:poll_answer, poll_game: game, poll_question: question, player:)
      round_started_at = 20.seconds.ago
      round_closed_at = Time.current
      answer.submitted_at = round_closed_at - 0.1.seconds
      points = answer.calculate_points(round_started_at:, round_closed_at:)
      expect(points).to be >= PollGame::MINIMUM_POINTS
      expect(points).to be <= PollGame::MAXIMUM_POINTS
    end
  end
end
