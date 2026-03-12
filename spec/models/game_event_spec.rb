require "rails_helper"

RSpec.describe GameEvent do
  describe ".log" do
    it "creates an event record" do
      game = create(:speed_trivia_game)

      expect {
        described_class.log(game, "state_changed", from: "waiting", to: "answering")
      }.to change(described_class, :count).by(1)

      event = described_class.last
      expect(event.eventable).to eq(game)
      expect(event.event_name).to eq("state_changed")
      expect(event.metadata).to eq("from" => "waiting", "to" => "answering")
    end

    it "does not raise on failure" do
      expect {
        described_class.log(nil, "state_changed")
      }.not_to raise_error
    end
  end
end
