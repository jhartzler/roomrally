require "rails_helper"

RSpec.describe GameEvent do
  describe "SpeedTrivia tracking" do
    let(:room) { create(:room, game_type: "Speed Trivia") }

    before do
      create_list(:player, 3, room:)
      pack = create(:trivia_pack, :default)
      create_list(:trivia_question, 5, trivia_pack: pack)
      room.update!(trivia_pack: pack)
    end

    context "when game_started is called" do
      it "creates a game_created event" do
        expect { Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true) }
          .to change(described_class, :count).by(1)
      end

      it "records event name and game type in metadata" do
        Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true)
        event = described_class.last
        expect(event.event_name).to eq("game_created")
        expect(event.metadata["game_type"]).to eq("Speed Trivia")
      end
    end

    context "when start_from_instructions is called" do
      before { Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true) }

      let(:game) { room.reload.current_game }

      it "logs a state_changed event" do
        expect { Games::SpeedTrivia.start_from_instructions(game:) }
          .to change(described_class, :count)
      end

      it "records transition to waiting" do
        Games::SpeedTrivia.start_from_instructions(game:)
        expect(described_class.where(event_name: "state_changed").last.metadata["to"]).to eq("waiting")
      end
    end

    context "when start_question is called" do
      before { Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false) }

      let(:game) { room.reload.current_game }

      it "logs a state_changed event" do
        expect { Games::SpeedTrivia.start_question(game:) }
          .to change(described_class, :count)
      end

      it "records transition to answering" do
        Games::SpeedTrivia.start_question(game:)
        expect(described_class.where(event_name: "state_changed").last.metadata["to"]).to eq("answering")
      end
    end

    context "when close_round is called" do
      before do
        Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
        game = room.reload.current_game
        Games::SpeedTrivia.start_question(game:)
      end

      let(:game) { room.reload.current_game }

      it "logs a state_changed event" do
        expect { Games::SpeedTrivia.close_round(game:) }
          .to change(described_class, :count)
      end

      it "records transition to reviewing" do
        Games::SpeedTrivia.close_round(game:)
        expect(described_class.where(event_name: "state_changed").last.metadata["to"]).to eq("reviewing")
      end
    end

    context "when next_question is called on the last question" do
      before do
        Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false, question_count: 1)
        game = room.reload.current_game
        Games::SpeedTrivia.start_question(game:)
        Games::SpeedTrivia.close_round(game:)
      end

      let(:game) { room.reload.current_game }

      it "logs a game_finished event" do
        expect { Games::SpeedTrivia.next_question(game:) }
          .to change { described_class.where(event_name: "game_finished").count }.by(1)
      end
    end
  end

  describe "WriteAndVote tracking" do
    let(:room) { create(:room, game_type: "Write And Vote") }

    before do
      create_list(:player, 3, room:)
      pack = create(:prompt_pack, :default)
      create_list(:prompt, 3, prompt_pack: pack)
      room.update!(prompt_pack: pack)
    end

    context "when game_started is called" do
      it "creates a game_created event" do
        expect { Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true) }
          .to change(described_class, :count).by(1)
      end

      it "records event name as game_created" do
        Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true)
        expect(described_class.last.event_name).to eq("game_created")
      end
    end

    context "when start_from_instructions is called" do
      before { Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true) }

      let(:game) { room.reload.current_game }

      it "logs a state_changed event" do
        expect { Games::WriteAndVote.start_from_instructions(game:) }
          .to change(described_class, :count)
      end

      it "records transition to writing" do
        Games::WriteAndVote.start_from_instructions(game:)
        expect(described_class.where(event_name: "state_changed").last.metadata["to"]).to eq("writing")
      end
    end
  end

  describe "CategoryList tracking" do
    let(:room) { create(:room, game_type: "Category List") }

    before do
      create_list(:player, 3, room:)
      pack = create(:category_pack, :default)
      create_list(:category, 10, category_pack: pack)
      room.update!(category_pack: pack)
    end

    context "when game_started is called" do
      it "creates a game_created event" do
        expect { Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true) }
          .to change(described_class, :count).by(1)
      end

      it "records event name as game_created" do
        Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true)
        expect(described_class.last.event_name).to eq("game_created")
      end
    end

    context "when start_from_instructions is called" do
      before { Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true) }

      let(:game) { room.reload.current_game }

      it "logs a state_changed event" do
        expect { Games::CategoryList.start_from_instructions(game:) }
          .to change(described_class, :count)
      end

      it "records transition to filling" do
        Games::CategoryList.start_from_instructions(game:)
        expect(described_class.where(event_name: "state_changed").last.metadata["to"]).to eq("filling")
      end
    end
  end
end
