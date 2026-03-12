require "rails_helper"

RSpec.describe SessionRecap do
  describe ".for" do
    context "with players in a room" do
      let(:room) { create(:room) }

      before do
        create(:player, room:, name: "Alice", created_at: 1.minute.from_now)
        create(:player, room:, name: "Bob", created_at: 2.minutes.from_now)
      end

      it "starts with room_created event" do
        expect(described_class.for(room).first.event_type).to eq("room_created")
      end

      it "includes player_joined events" do
        expect(described_class.for(room).map(&:event_type)).to include("player_joined")
      end
    end

    context "with game events" do
      let(:room) { create(:room, game_type: "Speed Trivia") }
      let(:game) { create(:speed_trivia_game) }

      before do
        room.update!(current_game: game)
        GameEvent.log(game, "game_created", game_type: "Speed Trivia", player_count: 3)
        GameEvent.log(game, "state_changed", from: "instructions", to: "waiting")
      end

      it "includes game events in the recap" do
        types = described_class.for(room).map(&:event_type)
        expect(types).to include("game_created", "state_changed")
      end
    end

    context "with speed trivia answer submissions" do
      let(:room) { create(:room, game_type: "Speed Trivia") }
      let(:game) { create(:speed_trivia_game) }
      let(:question) { create(:trivia_question_instance, speed_trivia_game: game) }
      let(:player) { create(:player, room:) }

      before do
        room.update!(current_game: game)
        create(:trivia_answer, trivia_question_instance: question, player:, submitted_at: Time.current)
      end

      it "includes answer_submitted events" do
        expect(described_class.for(room).map(&:event_type)).to include("answer_submitted")
      end
    end

    context "with votes in write and vote" do
      let(:room) { create(:room, game_type: "Write And Vote") }
      let(:game) { create(:write_and_vote_game) }
      let(:prompt) { create(:prompt_instance, write_and_vote_game: game) }
      let(:player) { create(:player, room:) }
      let(:voter) { create(:player, room:, name: "Voter") }

      before do
        room.update!(current_game: game)
        response = create(:response, prompt_instance: prompt, player:)
        create(:vote, response:, player: voter)
      end

      it "includes vote_cast events" do
        expect(described_class.for(room).map(&:event_type)).to include("vote_cast")
      end
    end

    it "returns an empty array for a room with no activity" do
      room = create(:room)
      events = described_class.for(room)

      expect(events.length).to eq(1) # just room_created
      expect(events.first.event_type).to eq("room_created")
    end
  end
end
