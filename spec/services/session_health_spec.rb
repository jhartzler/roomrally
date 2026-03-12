require "rails_helper"

RSpec.describe SessionHealth do
  describe ".check" do
    context "with a healthy finished game" do
      let(:room) { create(:room, status: :finished, game_type: "Speed Trivia") }
      let(:game) { create(:speed_trivia_game, status: :finished) }
      let(:player) { create(:player, room:) }
      let(:question) { create(:trivia_question_instance, speed_trivia_game: game) }

      before do
        room.update!(current_game: game)
        create(:trivia_answer, trivia_question_instance: question, player:, submitted_at: Time.current)
      end

      it "returns an empty flags array" do
        expect(described_class.check(room)).to be_empty
      end
    end

    context "with game stuck in non-terminal state" do
      let(:room) { create(:room, status: :playing, game_type: "Speed Trivia") }
      let(:game) { create(:speed_trivia_game, status: :answering, updated_at: 45.minutes.ago) }
      let(:flags) { described_class.check(room) }

      before { room.update!(current_game: game) }

      it "flags the game as stuck" do
        expect(flags.any? { |f| f.description.include?("stuck") }).to be true
      end

      it "marks the flag as error severity" do
        expect(flags.first.severity).to eq(:error)
      end
    end

    it "flags room that never started a game" do
      room = create(:room, status: :lobby)
      create(:player, room:)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("never started") }).to be true
    end

    context "when a player has zero submissions" do
      let(:room) { create(:room, status: :finished, game_type: "Speed Trivia") }
      let(:game) { create(:speed_trivia_game, status: :finished) }

      before do
        room.update!(current_game: game)
        create(:player, room:, name: "Ghost")
        create(:trivia_question_instance, speed_trivia_game: game)
      end

      it "flags Ghost as having 0 submissions" do
        flags = described_class.check(room)
        expect(flags.any? { |f| f.description.include?("Ghost") && f.description.include?("0 submissions") }).to be true
      end
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
