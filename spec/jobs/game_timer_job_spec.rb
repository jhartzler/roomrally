require 'rails_helper'

RSpec.describe GameTimerJob, type: :job do
  describe "#perform" do
    let(:game) { instance_double("WriteAndVoteGame") }
    let(:round_number) { 1 }
    let(:step_number) { 2 }

    it "delegates to game.process_timeout" do
      allow(game).to receive(:process_timeout)

      described_class.perform_now(game, round_number, step_number)

      expect(game).to have_received(:process_timeout).with(round_number, step_number)
    end

    it "handles nil game gracefully" do
      expect {
        described_class.perform_now(nil, round_number)
      }.not_to raise_error
    end

    it "works without step_number" do
        allow(game).to receive(:process_timeout)
        described_class.perform_now(game, round_number)
        expect(game).to have_received(:process_timeout).with(round_number, nil)
    end
  end
end
