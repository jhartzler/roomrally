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

    it 'does not calculate points at submission time (deferred to close_round)' do
      freeze_time do
        game.update!(round_started_at: Time.current)
        described_class.submit_answer(game:, player:, selected_option: "Paris")
        expect(TriviaAnswer.last.points_awarded).to eq(0)
      end
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

  describe '.assign_questions' do
    let(:pack) { create(:trivia_pack) }
    let(:game) { create(:speed_trivia_game, trivia_pack: pack) }

    context 'when a question has an image' do
      it 'copies the image blob to the question instance' do
        question = create(:trivia_question, trivia_pack: pack)
        question.image.attach(
          io: StringIO.new("fake image"),
          filename: "test.jpg",
          content_type: "image/jpeg"
        )

        described_class.send(:assign_questions, game:, question_count: 1)

        instance = game.trivia_question_instances.first
        expect(instance.image).to be_attached
        expect(instance.image.blob).to eq(question.image.blob)
      end
    end

    context 'when a question has no image' do
      it 'creates an instance with no image' do
        create(:trivia_question, trivia_pack: pack)

        described_class.send(:assign_questions, game:, question_count: 1)

        instance = game.trivia_question_instances.first
        expect(instance.image).not_to be_attached
      end
    end

    context 'when questions have explicit positions' do
      it 'assigns instances in position order, not id order' do
        create(:trivia_question, trivia_pack: pack, body: "Last",   position: 2)
        create(:trivia_question, trivia_pack: pack, body: "First",  position: 0)
        create(:trivia_question, trivia_pack: pack, body: "Middle", position: 1)

        described_class.send(:assign_questions, game:, question_count: 3)

        bodies = game.trivia_question_instances.order(:position).map(&:body)
        expect(bodies).to eq([ "First", "Middle", "Last" ])
      end
    end

    context 'when questions have no position set' do
      it 'assigns instances in id order' do
        create(:trivia_question, trivia_pack: pack, body: "First",  position: nil)
        create(:trivia_question, trivia_pack: pack, body: "Second", position: nil)
        create(:trivia_question, trivia_pack: pack, body: "Third",  position: nil)

        described_class.send(:assign_questions, game:, question_count: 3)

        bodies = game.trivia_question_instances.order(:position).map(&:body)
        expect(bodies).to eq([ "First", "Second", "Third" ])
      end
    end
  end

  describe '.close_round' do
    let(:game) { create(:speed_trivia_game, status: "answering") }
    let!(:room) { create(:room, current_game: game, game_type: "Speed Trivia") }

    before do
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

    it 'calculates points based on actual round duration and updates player scores' do
      freeze_time do
        started = Time.current - 5.seconds
        game.update!(round_started_at: started)
        player = create(:player, room:, score: 0)
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        # Answer submitted instantly (0s elapsed) — should get 1000 points
        create(:trivia_answer, player:, trivia_question_instance: question,
               correct: true, submitted_at: started, points_awarded: 0)

        described_class.close_round(game:)
        expect(TriviaAnswer.last.points_awarded).to eq(1000)
        expect(player.reload.score).to eq(1000)
      end
    end

    it 'awards fewer points to slower answers' do
      freeze_time do
        started = Time.current - 10.seconds
        game.update!(round_started_at: started)
        player = create(:player, room:, score: 0)
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        # Answer submitted at halfway (5s of 10s round) — should get 550 points
        create(:trivia_answer, player:, trivia_question_instance: question,
               correct: true, submitted_at: started + 5.seconds, points_awarded: 0)

        described_class.close_round(game:)
        expect(TriviaAnswer.last.points_awarded).to eq(550)
      end
    end

    it 'awards 0 points for incorrect answers' do
      freeze_time do
        started = Time.current - 5.seconds
        game.update!(round_started_at: started)
        player = create(:player, room:, score: 0)
        question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
        create(:trivia_answer, player:, trivia_question_instance: question,
               correct: false, submitted_at: started + 1.second, points_awarded: 0)

        described_class.close_round(game:)
        expect(TriviaAnswer.last.points_awarded).to eq(0)
        expect(player.reload.score).to eq(0)
      end
    end

    it 'captures previous_top_player_ids on the game instance before updating scores' do
      player = create(:player, room:, score: 1000)

      described_class.close_round(game:)

      expect(game.previous_top_player_ids).to include(player.id)
    end
  end

  describe '.finish_game!' do
    let(:game) { create(:speed_trivia_game, status: "answering") }
    let!(:room) { create(:room, current_game: game, game_type: "Speed Trivia", status: "playing") }

    before do
      create(:player, room:).tap { |p| room.update!(host: p) }
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
      allow(GameBroadcaster).to receive(:broadcast_stage_lobby)
      allow(GameBroadcaster).to receive(:broadcast_lobby)
    end

    context 'with scoreable data' do
      let!(:question) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }
      let!(:player) { create(:player, room:, score: 0) }

      before do
        create(:trivia_answer, player:, trivia_question_instance: question, points_awarded: 800)
      end

      it 'finishes the game' do
        described_class.finish_game!(game:)
        expect(game.reload.status).to eq("finished")
      end

      it 'finishes the room' do
        described_class.finish_game!(game:)
        expect(room.reload.status).to eq("finished")
      end

      it 'calculates scores' do
        described_class.finish_game!(game:)
        expect(player.reload.score).to eq(800)
      end

      it 'logs a game_finished event' do
        described_class.finish_game!(game:)
        event = GameEvent.find_by(eventable: game, event_name: "game_finished")
        expect(event).to be_present
        expect(event.metadata["details"]).to eq("ended by host")
      end

      it 'broadcasts game state' do
        described_class.finish_game!(game:)
        expect(GameBroadcaster).to have_received(:broadcast_stage)
      end
    end

    context 'without scoreable data' do
      it 'destroys the game' do
        expect { described_class.finish_game!(game:) }.to change(SpeedTriviaGame, :count).by(-1)
      end

      it 'resets room to lobby' do
        described_class.finish_game!(game:)
        expect(room.reload.status).to eq("lobby")
      end

      it 'nils out current_game' do
        described_class.finish_game!(game:)
        expect(room.reload.current_game).to be_nil
      end

      it 'broadcasts lobby state' do
        described_class.finish_game!(game:)
        expect(GameBroadcaster).to have_received(:broadcast_lobby).with(room:)
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
