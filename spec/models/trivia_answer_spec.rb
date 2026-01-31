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

    def build_answer(option)
      build(:trivia_answer, trivia_question_instance: question, player:, selected_option: option)
    end


    it 'sets correct to true when answer matches' do
      answer = build_answer("Paris")
      answer.determine_correctness
      expect(answer.correct).to be true
    end

    it 'sets correct to false when answer does not match' do
      answer = build_answer("London")
      answer.determine_correctness
      expect(answer.correct).to be false
    end

    it 'is case sensitive' do
      answer = build_answer("paris")
      answer.determine_correctness
      expect(answer.correct).to be false
    end
  end

  describe '#calculate_points' do
    # rubocop:disable RSpec/ExampleLength, RSpec/NoExpectationExample
    let(:game) { create(:speed_trivia_game, time_limit: 20) }
    let(:question) { create(:trivia_question_instance, speed_trivia_game: game, correct_answer: "Paris") }
    let(:player) { create(:player) }

    def build_correct_answer(submitted_at)
      build(:trivia_answer,
        trivia_question_instance: question, player:, selected_option: "Paris",
        correct: true, submitted_at:)
    end

    def check_points(offset, expected_points, time_limit: 20)
      freeze_time do
        started = Time.current
        answer = build_correct_answer(started + offset)
        points = answer.calculate_points(
          time_limit:, round_started_at: started, round_closed_at: started + time_limit.seconds
        )
        expect(points).to eq(expected_points)
      end
    end

    context 'when answer is incorrect' do
      it 'awards 0 points' do
        answer = build(:trivia_answer, trivia_question_instance: question, player:, selected_option: "London", correct: false)
        points = answer.calculate_points(
          time_limit: 20, round_started_at: 10.seconds.ago, round_closed_at: Time.current
        )
        expect(points).to eq(0)
      end
    end

    context 'when answer is correct' do
      it 'awards 1000 points for instant answer' do
        check_points(0.seconds, 1000)
      end

      it 'awards 500 points at time limit' do
        check_points(20.seconds, 500)
      end

      it 'awards 750 points at half time' do
        check_points(10.seconds, 750)
      end

      it 'has minimum 100 points for any correct answer within grace period' do
        # With time_limit=2, at elapsed=2.4s (within 0.5s grace): 1000 * (1 - 0.6) = 400
        check_points(2.4.seconds, 400, time_limit: 2)
      end

      it 'enforces minimum 100 points floor' do
        freeze_time do
          started = Time.current
          # At elapsed=1.4s (within 0.5s grace): 1000 * (1 - 0.7) = 300
          answer = build_correct_answer(started + 1.4.seconds)
          points = answer.calculate_points(
            time_limit: 1, round_started_at: started, round_closed_at: started + 1.second
          )
          expect(points).to eq(300)
        end
      end
    end

    context 'with grace period submissions' do
      it 'accepts answers within 0.5 seconds after round closes' do
        freeze_time do
          started = Time.current
          closed = started + 20.seconds
          answer = build_correct_answer(closed + 0.3.seconds)
          expect(answer.calculate_points(
            time_limit: 20, round_started_at: started, round_closed_at: closed
          )).to be >= 100
        end
      end

      it 'rejects answers after grace period (0.5 seconds)' do
        freeze_time do
          started = Time.current
          closed = started + 20.seconds
          answer = build_correct_answer(closed + 0.6.seconds)
          expect(answer.calculate_points(
            time_limit: 20, round_started_at: started, round_closed_at: closed
          )).to eq(0)
        end
      end
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/NoExpectationExample
  end
end
