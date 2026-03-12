require "rails_helper"

RSpec.describe SessionHealth do
  describe ".check" do
    it "returns empty array for healthy finished game" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :finished)
      room.update!(current_game: game)
      player = create(:player, room: room)
      question = create(:trivia_question_instance, speed_trivia_game: game)
      create(:trivia_answer, trivia_question_instance: question, player: player, submitted_at: Time.current)

      flags = described_class.check(room)
      expect(flags).to be_empty
    end

    it "flags game stuck in non-terminal state" do
      room = create(:room, status: :playing, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :answering, updated_at: 45.minutes.ago)
      room.update!(current_game: game)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("stuck") }).to be true
      expect(flags.first.severity).to eq(:error)
    end

    it "flags room that never started a game" do
      room = create(:room, status: :lobby)
      create(:player, room: room)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("never started") }).to be true
    end

    it "flags player with zero submissions" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :finished)
      room.update!(current_game: game)
      create(:player, room: room, name: "Ghost")
      create(:trivia_question_instance, speed_trivia_game: game)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("Ghost") && f.description.include?("0 submissions") }).to be true
    end

    it "flags abandoned mid-game" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :answering)
      room.update!(current_game: game)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.severity == :error && f.description.include?("abandoned") }).to be true
    end

    it "returns no flags for room with no players and no game" do
      room = create(:room, status: :lobby)
      flags = described_class.check(room)
      expect(flags).to be_empty
    end
  end
end
