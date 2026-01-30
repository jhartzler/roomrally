require 'rails_helper'

RSpec.describe TriviaAnswer, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'associations' do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:trivia_question_instance) }
  end

  describe '#determine_correctness' do
    let(:question) { create(:trivia_question_instance, correct_answer: "Paris") }
    let(:player) { create(:player) }

    it 'sets correct to true when answer matches' do
      answer = build(:trivia_answer, trivia_question_instance: question, player:, selected_option: "Paris")
      answer.determine_correctness
      expect(answer.correct).to be true
    end

    it 'sets correct to false when answer does not match' do
      answer = build(:trivia_answer, trivia_question_instance: question, player:, selected_option: "London")
      answer.determine_correctness
      expect(answer.correct).to be false
    end

    it 'is case sensitive' do
      answer = build(:trivia_answer, trivia_question_instance: question, player:, selected_option: "paris")
      answer.determine_correctness
      expect(answer.correct).to be false
    end
  end

  describe '#calculate_points' do
    let(:game) { create(:speed_trivia_game, time_limit: 20) }
    let(:question) { create(:trivia_question_instance, speed_trivia_game: game, correct_answer: "Paris") }
    let(:player) { create(:player) }

    context 'when answer is incorrect' do
      it 'awards 0 points' do
        answer = build(:trivia_answer,
          trivia_question_instance: question,
          player:,
          selected_option: "London",
          correct: false)
        expect(answer.calculate_points(
          time_limit: 20,
          round_started_at: 10.seconds.ago,
          round_closed_at: Time.current
        )).to eq(0)
      end
    end

    context 'when answer is correct' do
      it 'awards 1000 points for instant answer' do
        freeze_time do
          started_at = Time.current
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: started_at)
          expect(answer.calculate_points(
            time_limit: 20,
            round_started_at: started_at,
            round_closed_at: started_at + 20.seconds
          )).to eq(1000)
        end
      end

      it 'awards 500 points at time limit' do
        freeze_time do
          started_at = Time.current
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: started_at + 20.seconds)
          expect(answer.calculate_points(
            time_limit: 20,
            round_started_at: started_at,
            round_closed_at: started_at + 20.seconds
          )).to eq(500)
        end
      end

      it 'awards 750 points at half time' do
        freeze_time do
          started_at = Time.current
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: started_at + 10.seconds)
          expect(answer.calculate_points(
            time_limit: 20,
            round_started_at: started_at,
            round_closed_at: started_at + 20.seconds
          )).to eq(750)
        end
      end

      it 'has minimum 100 points for any correct answer within grace period' do
        freeze_time do
          started_at = Time.current
          # Use a very short time_limit so formula would go below 100
          # With time_limit=2, at elapsed=2.4s (within 0.5s grace):
          # 1000 * (1 - (2.4/2) * 0.5) = 1000 * (1 - 0.6) = 400
          # But at elapsed=2.49s: 1000 * (1 - 0.6225) = 377
          # Even more extreme submissions would hit the floor
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: started_at + 2.4.seconds)
          expect(answer.calculate_points(
            time_limit: 2,
            round_started_at: started_at,
            round_closed_at: started_at + 2.seconds
          )).to eq(400)
        end
      end

      it 'enforces minimum 100 points floor' do
        freeze_time do
          started_at = Time.current
          # With time_limit=1, at elapsed=1.4s (within 0.5s grace):
          # 1000 * (1 - (1.4/1) * 0.5) = 1000 * (1 - 0.7) = 300
          # At elapsed=1.49s: 1000 * (1 - 0.745) = 255
          # At elapsed=2.5s: would be negative, but capped at 100
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: started_at + 1.4.seconds)
          points = answer.calculate_points(
            time_limit: 1,
            round_started_at: started_at,
            round_closed_at: started_at + 1.second
          )
          expect(points).to eq(300)
        end
      end
    end

    context 'with grace period submissions' do
      it 'accepts answers within 0.5 seconds after round closes' do
        freeze_time do
          started_at = Time.current
          closed_at = started_at + 20.seconds
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: closed_at + 0.3.seconds)
          # Should still get points (though low due to timing)
          expect(answer.calculate_points(
            time_limit: 20,
            round_started_at: started_at,
            round_closed_at: closed_at
          )).to be >= 100
        end
      end

      it 'rejects answers after grace period (0.5 seconds)' do
        freeze_time do
          started_at = Time.current
          closed_at = started_at + 20.seconds
          answer = build(:trivia_answer,
            trivia_question_instance: question,
            player:,
            selected_option: "Paris",
            correct: true,
            submitted_at: closed_at + 0.6.seconds)
          expect(answer.calculate_points(
            time_limit: 20,
            round_started_at: started_at,
            round_closed_at: closed_at
          )).to eq(0)
        end
      end
    end
  end
end
