require "rails_helper"

RSpec.describe GameEvent do
  describe ".log" do
    let(:game) { create(:speed_trivia_game) }

    it "creates a new event record" do
      expect { described_class.log(game, "state_changed", from: "waiting", to: "answering") }
        .to change(described_class, :count).by(1)
    end

    it "associates the event with the game" do
      described_class.log(game, "state_changed", from: "waiting", to: "answering")
      expect(described_class.last.eventable).to eq(game)
    end

    it "stores the event name" do
      described_class.log(game, "state_changed", from: "waiting", to: "answering")
      expect(described_class.last.event_name).to eq("state_changed")
    end

    it "stores event metadata" do
      described_class.log(game, "state_changed", from: "waiting", to: "answering")
      expect(described_class.last.metadata).to eq("from" => "waiting", "to" => "answering")
    end

    it "does not raise on failure" do
      expect { described_class.log(nil, "state_changed") }.not_to raise_error
    end
  end
end
