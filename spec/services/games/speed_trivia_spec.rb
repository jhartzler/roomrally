require 'rails_helper'

RSpec.describe Games::SpeedTrivia do
  include ActiveSupport::Testing::TimeHelpers

  describe '.game_started' do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let(:default_pack) { create(:trivia_pack, :default) }

    before do
      create_list(:player, 3, room:)
      10.times { |i| create(:trivia_question, trivia_pack: default_pack, body: "Question #{i + 1}?") }
      allow(GameBroadcaster).to receive(:broadcast_game_start)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
    end

    it 'creates a SpeedTriviaGame and associates it with the room' do
      expect { described_class.game_started(room:) }.to change(SpeedTriviaGame, :count).by(1)
      expect(room.reload.current_game).to be_a(SpeedTriviaGame)
    end

    it 'is idempotent (does not create duplicates if called twice)' do
      described_class.game_started(room:)
      expect { described_class.game_started(room:) }.not_to change(SpeedTriviaGame, :count)
    end

    it 'assigns questions as TriviaQuestionInstances' do
      described_class.game_started(room:, question_count: 3)
      expect(TriviaQuestionInstance.count).to eq(3)
    end

    it 'creates questions with sequential positions' do
      described_class.game_started(room:, question_count: 3)
      positions = TriviaQuestionInstance.order(:position).pluck(:position)
      expect(positions).to eq([ 0, 1, 2 ])
    end

    it 'starts in instructions state by default' do
      described_class.game_started(room:)
      expect(room.current_game.status).to eq("instructions")
    end

    it 'starts in waiting state when show_instructions is false' do
      described_class.game_started(room:, show_instructions: false)
      expect(room.current_game.status).to eq("waiting")
    end

    context 'when there are not enough questions' do
      before { TriviaQuestion.destroy_all }

      it 'raises an error' do
        expect { described_class.game_started(room:, question_count: 5) }
          .to raise_error("Not enough trivia questions to start game.")
      end
    end
  end

  describe '.start_question' do
    let(:game) { create(:speed_trivia_game, status: "waiting") }
    let(:room) { create(:room, current_game: game, game_type: "Speed Trivia") }

    before do
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
    end

    it 'transitions to answering state' do
      described_class.start_question(game:)
      expect(game.reload.status).to eq("answering")
    end

    it 'sets round_started_at' do
      freeze_time do
        described_class.start_question(game:)
        expect(game.reload.round_started_at).to eq(Time.current)
      end
    end
  end

  describe '.submit_answer' do
    let(:game) { create(:speed_trivia_game, status: "answering", time_limit: 20) }
    let(:room) { create(:room, current_game: game, game_type: "Speed Trivia") }
    let!(:player) { create(:player, room:) }

    before do
      create(:trivia_question_instance,
        speed_trivia_game: game,
        position: 0,
        correct_answers: [ "Paris" ],
        options: [ "Paris", "London", "Berlin", "Madrid" ])
      game.update!(round_started_at: 5.seconds.ago)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
    end

    it 'creates a TriviaAnswer' do
      expect {
        described_class.submit_answer(game:, player:, selected_option: "Paris")
      }.to change(TriviaAnswer, :count).by(1)
    end

    it 'determines correctness' do
      described_class.submit_answer(game:, player:, selected_option: "Paris")
      answer = TriviaAnswer.last
      expect(answer.correct).to be true
    end

    it 'calculates and stores points for correct answer' do
      freeze_time do
        game.update!(round_started_at: Time.current)
        described_class.submit_answer(game:, player:, selected_option: "Paris")
        expect(TriviaAnswer.last.points_awarded).to eq(1000)
      end
    end

    it 'awards 0 points for incorrect answer' do
      described_class.submit_answer(game:, player:, selected_option: "London")
      answer = TriviaAnswer.last
      expect(answer.points_awarded).to eq(0)
    end

    it 'sets submitted_at timestamp' do
      freeze_time do
        described_class.submit_answer(game:, player:, selected_option: "Paris")
        answer = TriviaAnswer.last
        expect(answer.submitted_at).to eq(Time.current)
      end
    end

    it 'prevents duplicate answers from same player' do
      described_class.submit_answer(game:, player:, selected_option: "Paris")
      expect {
        described_class.submit_answer(game:, player:, selected_option: "London")
      }.not_to change(TriviaAnswer, :count)
    end
  end

  describe '.close_round' do
    let(:game) { create(:speed_trivia_game, status: "answering") }

    before do
      create(:room, current_game: game, game_type: "Speed Trivia")
      game.update!(round_started_at: 10.seconds.ago)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
    end

    it 'transitions to reviewing state' do
      described_class.close_round(game:)
      expect(game.reload.status).to eq("reviewing")
    end

    it 'sets round_closed_at' do
      freeze_time do
        described_class.close_round(game:)
        expect(game.reload.round_closed_at).to eq(Time.current)
      end
    end
  end

  describe '.next_question' do
    let(:game) { create(:speed_trivia_game, status: "reviewing", current_question_index: 0) }
    let!(:room) { create(:room, current_game: game, game_type: "Speed Trivia") }

    before do
      create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_question_instance, speed_trivia_game: game, position: 1)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
    end

    context 'when more questions remain' do
      it 'increments current_question_index' do
        described_class.next_question(game:)
        expect(game.reload.current_question_index).to eq(1)
      end

      it 'transitions to answering state' do
        described_class.next_question(game:)
        expect(game.reload.status).to eq("answering")
      end

      it 'sets round_started_at for new question' do
        freeze_time do
          described_class.next_question(game:)
          expect(game.reload.round_started_at).to eq(Time.current)
        end
      end
    end

    context 'when no more questions' do
      before { game.update!(current_question_index: 1) }

      it 'finishes the game' do
        described_class.next_question(game:)
        expect(game.reload.status).to eq("finished")
      end

      it 'finishes the room' do
        room.update!(status: 'playing')
        described_class.next_question(game:)
        expect(room.reload.status).to eq("finished")
      end

      it 'calculates final scores' do
        player = create(:player, room:, score: 0)
        first_question = game.trivia_question_instances.find_by(position: 0)
        create(:trivia_answer, player:, trivia_question_instance: first_question, points_awarded: 800)

        described_class.next_question(game:)
        expect(player.reload.score).to eq(800)
      end
    end
  end
end
