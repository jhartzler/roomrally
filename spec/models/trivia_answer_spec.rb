require 'rails_helper'

RSpec.describe TriviaAnswer, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'associations' do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:trivia_question_instance) }
  end

  describe '#determine_correctness' do
    let(:player) { create(:player) }

    context 'with single correct answer' do
      let(:question) { create(:trivia_question_instance, correct_answers: [ "Paris" ]) }

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

    context 'with multiple correct answers' do
      let(:question) { create(:trivia_question_instance, correct_answers: [ "Paris", "Berlin" ]) }

      def build_answer(option)
        build(:trivia_answer, trivia_question_instance: question, player:, selected_option: option)
      end

      it 'sets correct to true when answer matches first correct answer' do
        answer = build_answer("Paris")
        answer.determine_correctness
        expect(answer.correct).to be true
      end

      it 'sets correct to true when answer matches second correct answer' do
        answer = build_answer("Berlin")
        answer.determine_correctness
        expect(answer.correct).to be true
      end

      it 'sets correct to false when answer matches no correct answer' do
        answer = build_answer("London")
        answer.determine_correctness
        expect(answer.correct).to be false
      end
    end
  end

  describe '#calculate_points' do
    # rubocop:disable RSpec/ExampleLength, RSpec/NoExpectationExample
    let(:game) { create(:speed_trivia_game, time_limit: 20) }
    let(:question) { create(:trivia_question_instance, speed_trivia_game: game, correct_answers: [ "Paris" ]) }
    let(:player) { create(:player) }

    def build_correct_answer(submitted_at)
      build(:trivia_answer,
        trivia_question_instance: question, player:, selected_option: "Paris",
        correct: true, submitted_at:)
    end

    def check_points(offset, round_duration, expected_points)
      freeze_time do
        started = Time.current
        answer = build_correct_answer(started + offset)
        points = answer.calculate_points(
          round_started_at: started, round_closed_at: started + round_duration.seconds
        )
        expect(points).to eq(expected_points)
      end
    end

    context 'when answer is incorrect' do
      it 'awards 0 points' do
        answer = build(:trivia_answer, trivia_question_instance: question, player:, selected_option: "London", correct: false)
        points = answer.calculate_points(
          round_started_at: 10.seconds.ago, round_closed_at: Time.current
        )
        expect(points).to eq(0)
      end
    end

    context 'when answer is correct' do
      it 'awards 1000 points for instant answer' do
        check_points(0.seconds, 10, 1000)
      end

      it 'awards 100 points at round close time' do
        check_points(10.seconds, 10, 100)
      end

      it 'awards 550 points at half time' do
        check_points(5.seconds, 10, 550)
      end

      it 'scales based on actual round duration, not fixed time limit' do
        # Short round (3 seconds) — answer at 1.5s should get 550
        check_points(1.5.seconds, 3, 550)
        # Long round (30 seconds) — answer at 15s should also get 550
        check_points(15.seconds, 30, 550)
      end

      it 'awards max points when round duration is zero (instant close)' do
        freeze_time do
          started = Time.current
          answer = build_correct_answer(started)
          points = answer.calculate_points(
            round_started_at: started, round_closed_at: started
          )
          expect(points).to eq(1000)
        end
      end
    end

    context 'with grace period submissions' do
      it 'accepts answers within 0.5 seconds after round closes' do
        freeze_time do
          started = Time.current
          closed = started + 10.seconds
          answer = build_correct_answer(closed + 0.3.seconds)
          expect(answer.calculate_points(
            round_started_at: started, round_closed_at: closed
          )).to be >= 100
        end
      end

      it 'rejects answers after grace period (0.5 seconds)' do
        freeze_time do
          started = Time.current
          closed = started + 10.seconds
          answer = build_correct_answer(closed + 0.6.seconds)
          expect(answer.calculate_points(
            round_started_at: started, round_closed_at: closed
          )).to eq(0)
        end
      end
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/NoExpectationExample
  end
end
