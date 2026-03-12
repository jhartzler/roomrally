require "rails_helper"

RSpec.describe SessionRecap do
  describe ".for" do
    it "returns events ordered by timestamp" do
      room = create(:room)
      create(:player, room:, name: "Alice", created_at: 1.minute.from_now)
      create(:player, room:, name: "Bob", created_at: 2.minutes.from_now)

      events = described_class.for(room)

      expect(events.first.event_type).to eq("room_created")
      types = events.map(&:event_type)
      expect(types).to include("player_joined")
    end

    it "includes game events when present" do
      room = create(:room, game_type: "Speed Trivia")
      game = create(:speed_trivia_game)
      room.update!(current_game: game)
      GameEvent.log(game, "game_created", game_type: "Speed Trivia", player_count: 3)
      GameEvent.log(game, "state_changed", from: "instructions", to: "waiting")

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("game_created", "state_changed")
    end

    it "includes answer submissions for speed trivia" do
      room = create(:room, game_type: "Speed Trivia")
      game = create(:speed_trivia_game)
      room.update!(current_game: game)
      question = create(:trivia_question_instance, speed_trivia_game: game)
      player = create(:player, room:)
      create(:trivia_answer, trivia_question_instance: question, player:, submitted_at: Time.current)

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("answer_submitted")
    end

    it "includes votes for write and vote" do
      room = create(:room, game_type: "Write And Vote")
      game = create(:write_and_vote_game)
      room.update!(current_game: game)
      prompt = create(:prompt_instance, write_and_vote_game: game)
      player = create(:player, room:)
      response = create(:response, prompt_instance: prompt, player:)
      voter = create(:player, room:, name: "Voter")
      create(:vote, response:, player: voter)

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("vote_cast")
    end

    it "returns an empty array for a room with no activity" do
      room = create(:room)
      events = described_class.for(room)

      expect(events.length).to eq(1) # just room_created
      expect(events.first.event_type).to eq("room_created")
    end
  end
end
