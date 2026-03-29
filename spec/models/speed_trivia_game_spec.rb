require 'rails_helper'

RSpec.describe SpeedTriviaGame, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'associations' do
    it { is_expected.to have_one(:room) }
    it { is_expected.to belong_to(:trivia_pack).optional }
    it { is_expected.to have_many(:trivia_question_instances) }
    it { is_expected.to have_many(:trivia_answers) }
  end

  describe 'defaults' do
    it 'has default status instructions' do
      game = described_class.create!
      expect(game.status).to eq('instructions')
    end

    it 'has default current_question_index 0' do
      game = described_class.create!
      expect(game.current_question_index).to eq(0)
    end

    it 'has default time_limit 20' do
      game = described_class.create!
      expect(game.time_limit).to eq(20)
    end
  end

  describe 'state machine' do
    let(:game) { described_class.create! }

    it 'starts in instructions state' do
      expect(game.status).to eq('instructions')
    end

    describe 'start_game event' do
      it 'transitions from instructions to waiting' do
        expect(game.may_start_game?).to be true
        game.start_game!
        expect(game.status).to eq('waiting')
      end
    end

    describe 'start_question event' do
      before { game.start_game! }

      it 'transitions from waiting to answering' do
        expect(game.may_start_question?).to be true
        game.start_question!
        expect(game.status).to eq('answering')
      end

      it 'transitions from reviewing to answering' do
        game.update!(status: 'reviewing')
        expect(game.may_start_question?).to be true
        game.start_question!
        expect(game.status).to eq('answering')
      end
    end

    describe 'close_round event' do
      before { game.update!(status: 'answering') }

      it 'transitions from answering to reviewing' do
        expect(game.may_close_round?).to be true
        game.close_round!
        expect(game.status).to eq('reviewing')
      end

      it 'sets round_closed_at' do
        freeze_time do
          game.close_round!
          expect(game.round_closed_at).to eq(Time.current)
        end
      end
    end

    describe 'next_question event' do
      before { game.update!(status: 'reviewing') }

      it 'increments current_question_index' do
        expect { game.next_question! }.to change(game, :current_question_index).by(1)
      end

      it 'stays in reviewing state' do
        game.next_question!
        expect(game.status).to eq('reviewing')
      end
    end

    describe 'finish_game event' do
      before { game.update!(status: 'reviewing') }

      it 'transitions to finished' do
        expect(game.may_finish_game?).to be true
        game.finish_game!
        expect(game.status).to eq('finished')
      end
    end
  end

  describe '#current_question' do
    let(:game) { create(:speed_trivia_game) }
    let!(:first_question) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }
    let!(:second_question) { create(:trivia_question_instance, speed_trivia_game: game, position: 1) }

    it 'returns the question at current_question_index' do
      expect(game.current_question).to eq(first_question)
    end

    it 'returns the correct question after advancing' do
      game.update!(current_question_index: 1)
      expect(game.current_question).to eq(second_question)
    end

    it 'returns nil if no more questions' do
      game.update!(current_question_index: 99)
      expect(game.current_question).to be_nil
    end
  end

  describe '#questions_remaining?' do
    let(:game) { create(:speed_trivia_game) }

    before do
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_question_instance, speed_trivia_game: game, position: 1)
    end

    it 'returns true when more questions exist' do
      expect(game.questions_remaining?).to be true
    end

    it 'returns false when on last question' do
      game.update!(current_question_index: 1)
      expect(game.questions_remaining?).to be false
    end
  end

  describe '#all_answers_submitted?' do
    let(:game) { create(:speed_trivia_game) }
    let(:room) { create(:room, current_game: game) }
    let!(:alice) { create(:player, room:) }
    let!(:bob) { create(:player, room:) }
    let!(:question) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }

    context 'when no answers submitted' do
      it 'returns false' do
        expect(game.all_answers_submitted?).to be false
      end
    end

    context 'when some answers submitted' do
      before do
        create(:trivia_answer, player: alice, trivia_question_instance: question)
      end

      it 'returns false' do
        expect(game.all_answers_submitted?).to be false
      end
    end

    context 'when all answers submitted' do
      before do
        create(:trivia_answer, player: alice, trivia_question_instance: question)
        create(:trivia_answer, player: bob, trivia_question_instance: question)
      end

      it 'returns true' do
        expect(game.all_answers_submitted?).to be true
      end
    end

    context 'with pending approval players' do
      # rubocop:disable RSpec/ExampleLength
      it 'only counts active players' do
        alice.update!(status: :active)
        bob.update!(status: :active)
        create(:player, room:, status: :pending_approval)
        create(:trivia_answer, player: alice, trivia_question_instance: question)
        create(:trivia_answer, player: bob, trivia_question_instance: question)

        expect(game.all_answers_submitted?).to be true
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end

  describe 'HasRoundTimer' do
    let(:game) { create(:speed_trivia_game, timer_enabled: true, time_limit: 30) }

    before { create(:room, current_game: game, game_type: "Speed Trivia") }

    describe '#start_timer!' do
      it 'updates the game with duration and end time' do
        freeze_time do
          game.start_timer!(30)
          expect(game.timer_duration).to eq(30)
          expect(game.round_ends_at).to eq(30.seconds.from_now)
        end
      end

      it 'enqueues a GameTimerJob' do
        expect {
          game.start_timer!(30)
        }.to have_enqueued_job(GameTimerJob).with(game, 0, nil)
      end
    end

    describe '#time_remaining' do
      it 'returns 0 if no timer set' do
        game.update!(round_ends_at: nil)
        expect(game.time_remaining).to eq(0)
      end

      it 'returns correct seconds remaining' do
        freeze_time do
          game.update!(round_ends_at: 10.seconds.from_now)
          expect(game.time_remaining).to eq(10)
        end
      end
    end
  end

  describe '#process_timeout' do
    let(:game) { create(:speed_trivia_game, status: "answering") }

    before do
      create(:room, current_game: game, game_type: "Speed Trivia")
      allow(Games::SpeedTrivia).to receive(:handle_timeout)
    end

    it 'calls the service when question index matches' do
      game.process_timeout(0, nil)
      expect(Games::SpeedTrivia).to have_received(:handle_timeout).with(game:)
    end

    it 'ignores if question index does not match' do
      game.update!(current_question_index: 1)
      game.process_timeout(0, nil)
      expect(Games::SpeedTrivia).not_to have_received(:handle_timeout)
    end

    it 'ignores if not in answering state' do
      game.update!(status: "reviewing")
      game.process_timeout(0, nil)
      expect(Games::SpeedTrivia).not_to have_received(:handle_timeout)
    end
  end

  describe '#calculate_scores!' do
    let(:game) { create(:speed_trivia_game) }
    let(:room) { create(:room, current_game: game) }
    let!(:player) { create(:player, room:, score: 0) }
    let!(:question) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }

    it 'updates player scores based on points_awarded' do
      create(:trivia_answer, player:, trivia_question_instance: question, points_awarded: 800)
      game.calculate_scores!
      expect(player.reload.score).to eq(800)
    end

    it 'sums points across multiple questions' do
      question2 = create(:trivia_question_instance, speed_trivia_game: game, position: 1)
      create(:trivia_answer, player:, trivia_question_instance: question, points_awarded: 800)
      create(:trivia_answer, player:, trivia_question_instance: question2, points_awarded: 600)
      game.calculate_scores!
      expect(player.reload.score).to eq(1400)
    end

    # rubocop:disable RSpec/ExampleLength
    it 'only calculates scores for active players' do
      active = create(:player, room:, status: :active, score: 0)
      pending = create(:player, room:, status: :pending_approval, score: 0)
      create(:trivia_answer, player: active, trivia_question_instance: question, points_awarded: 800)
      create(:trivia_answer, player: pending, trivia_question_instance: question, points_awarded: 600)
      game.calculate_scores!

      expect(active.reload.score).to eq(800)
      expect(pending.reload.score).to eq(0)
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '#score_reveal_for' do
    let(:game) { create(:speed_trivia_game, status: "reviewing") }
    let(:room) { create(:room, current_game: game) }
    let!(:alice) { create(:player, room:, score: 0) }
    let!(:bob) { create(:player, room:, score: 0) }
    let!(:q1) { create(:trivia_question_instance, speed_trivia_game: game, position: 0, correct_answers: [ "Right" ]) }

    # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
    it 'returns score_from of 0 and positive score_to on first correct answer' do
      create(:trivia_answer, player: alice, trivia_question_instance: q1, points_awarded: 800, correct: true, selected_option: "Right")
      create(:trivia_answer, player: bob, trivia_question_instance: q1, points_awarded: 0, correct: false, selected_option: "Wrong")
      game.calculate_scores!

      reveal = game.score_reveal_for(player: alice)

      expect(reveal[:score_from]).to eq(0)
      expect(reveal[:score_to]).to eq(800)
      expect(reveal[:round_points]).to eq(800)
      expect(reveal[:rank]).to eq(1)
      expect(reveal[:answer]).to be_correct
    end

    it 'never produces negative score_from even with stale player.score' do
      create(:trivia_answer, player: alice, trivia_question_instance: q1, points_awarded: 500, correct: true, selected_option: "Right")
      # Intentionally skip calculate_scores! to simulate stale player.score

      reveal = game.score_reveal_for(player: alice)

      expect(reveal[:score_from]).to eq(0)
      expect(reveal[:score_to]).to eq(500)
    end

    it 'carries cumulative score across questions' do
      q2 = create(:trivia_question_instance, speed_trivia_game: game, position: 1, correct_answers: [ "Also Right" ])
      create(:trivia_answer, player: alice, trivia_question_instance: q1, points_awarded: 800, correct: true, selected_option: "Right")
      create(:trivia_answer, player: alice, trivia_question_instance: q2, points_awarded: 600, correct: true, selected_option: "Also Right")
      game.update!(current_question_index: 1)
      game.calculate_scores!

      reveal = game.score_reveal_for(player: alice)

      expect(reveal[:score_from]).to eq(800)
      expect(reveal[:score_to]).to eq(1400)
      expect(reveal[:round_points]).to eq(600)
    end

    it 'returns nil answer and 0 points when player did not answer' do
      reveal = game.score_reveal_for(player: alice)

      expect(reveal[:answer]).to be_nil
      expect(reveal[:round_points]).to eq(0)
      expect(reveal[:score_from]).to eq(0)
      expect(reveal[:score_to]).to eq(0)
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
  end

  describe '#has_scoreable_data?' do
    let(:game) { create(:speed_trivia_game) }

    it 'returns false when no trivia answers exist' do
      expect(game.has_scoreable_data?).to be false
    end

    it 'returns true when trivia answers exist' do
      room = create(:room, current_game: game)
      player = create(:player, room:)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, player:, trivia_question_instance: question)
      expect(game.has_scoreable_data?).to be true
    end
  end

  describe ".supports_response_moderation?" do
    it "returns false" do
      expect(described_class.supports_response_moderation?).to be false
    end
  end
end
