require 'rails_helper'

RSpec.describe AbandonedGameCleanupJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  describe "#perform" do
    let!(:recent_room) { create(:room, status: "playing") }
    let!(:stale_room) { create(:room, status: "playing") }
    let!(:finished_room) { create(:room, status: "finished") }

    context "when rooms have current games" do
      let!(:recent_game) { create(:write_and_vote_game, status: "writing") }
      let!(:stale_game) { create(:write_and_vote_game, status: "writing") }

      before do
        # Use update_columns to avoid automatic updated_at timestamp changes
        recent_room.update_columns(
          current_game_id: recent_game.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 1.hour.ago
        )
        stale_room.update_columns(
          current_game_id: stale_game.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 25.hours.ago
        )
        finished_room.update_column(:updated_at, 30.hours.ago)
      end

      it "does not finish recent rooms" do
        expect {
          described_class.perform_now
        }.not_to change { recent_room.reload.status }
      end

      it "finishes stale rooms and their games" do
        described_class.perform_now

        expect(stale_room.reload.status).to eq("finished")
        expect(stale_game.reload.status).to eq("finished")
      end

      it "does not process already finished rooms" do
        allow(finished_room).to receive(:finish!)
        described_class.perform_now
        expect(finished_room).not_to have_received(:finish!)
      end

      # rubocop:disable RSpec/ExampleLength
      it "processes rooms that were not updated in 24+ hours" do
        room_24h = create(:room, status: "playing")
        game_24h = create(:write_and_vote_game, status: "writing")
        room_24h.update_columns(
          current_game_id: game_24h.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 24.hours.ago
        )

        described_class.perform_now

        expect(room_24h.reload.status).to eq("finished")
      end

      it "handles games that cannot be finished gracefully" do
        # Create a room with a game in a state that can't transition to finished
        unfinishable_room = create(:room, status: "playing")
        # Game is already finished, so may_finish_game? will return false
        finished_game = create(:write_and_vote_game, status: "finished")
        unfinishable_room.update_columns(
          current_game_id: finished_game.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 25.hours.ago
        )

        expect {
          described_class.perform_now
        }.not_to raise_error

        # Room should still be finished even if game can't be
        expect(unfinishable_room.reload.status).to eq("finished")
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when rooms have no current game" do
      before do
        stale_room.update_columns(current_game_id: nil, current_game_type: nil, updated_at: 25.hours.ago)
      end

      it "finishes the room without a game" do
        described_class.perform_now
        expect(stale_room.reload.status).to eq("finished")
      end
    end

    context "with multiple stale rooms" do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:stale_with_write_and_vote) { create(:room, status: "playing") }
      let!(:stale_with_trivia) { create(:room, status: "playing") }
      let!(:stale_without_game) { create(:room, status: "playing") }

      before do
        write_and_vote_game_1 = create(:write_and_vote_game, status: "writing")
        write_and_vote_game_2 = create(:write_and_vote_game, status: "writing")
        trivia_game = create(:speed_trivia_game, status: "answering")

        stale_room.update_columns(
          current_game_id: write_and_vote_game_1.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 25.hours.ago
        )
        stale_with_write_and_vote.update_columns(
          current_game_id: write_and_vote_game_2.id,
          current_game_type: "WriteAndVoteGame",
          updated_at: 30.hours.ago
        )
        stale_with_trivia.update_columns(
          current_game_id: trivia_game.id,
          current_game_type: "SpeedTriviaGame",
          updated_at: 48.hours.ago
        )
        stale_without_game.update_columns(
          current_game_id: nil,
          current_game_type: nil,
          updated_at: 72.hours.ago
        )
      end

      # rubocop:disable RSpec/MultipleExpectations
      it "processes all stale rooms" do
        described_class.perform_now

        expect(stale_room.reload.status).to eq("finished")
        expect(stale_with_write_and_vote.reload.status).to eq("finished")
        expect(stale_with_trivia.reload.status).to eq("finished")
        expect(stale_without_game.reload.status).to eq("finished")
      end
      # rubocop:enable RSpec/MultipleExpectations

      it "finishes write and vote games" do
        described_class.perform_now
        expect(stale_with_write_and_vote.current_game.reload.status).to eq("finished")
      end

      it "finishes trivia games" do
        described_class.perform_now
        expect(stale_with_trivia.current_game.reload.status).to eq("finished")
      end
    end

    context "with rooms in lobby state" do
      let!(:stale_lobby) { create(:room, status: "lobby") }

      before do
        stale_lobby.update_column(:updated_at, 30.hours.ago)
      end

      it "does not finish rooms in lobby state (transition not allowed)" do
        described_class.perform_now
        expect(stale_lobby.reload.status).to eq("lobby")
      end
    end
  end
end
