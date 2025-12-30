require 'rails_helper'

RSpec.describe GameBroadcaster do
  describe ".broadcast_player_joined" do
    let(:room) { create(:room) }
    let(:player) { create(:player, room:) }

    it "does not leak session_id in the rendered keys or content" do
      # rubocop:disable RSpec/MessageSpies
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).at_least(:once).and_wrap_original do |m, *args|
        verify_no_session_leak(args, player.session_id)
        m.call(*args)
      end
      # rubocop:enable RSpec/MessageSpies

      described_class.broadcast_player_joined(room:, player:)
    end

    def verify_no_session_leak(args, session_id)
      kwargs = args.last.is_a?(Hash) ? args.last : {}
      return unless kwargs[:partial]

      content = ApplicationController.renderer.render(
        partial: kwargs[:partial],
        locals: kwargs[:locals]
      )
      expect(content).not_to include(session_id)
    end
  end

  describe "Player JSON serialization" do
    let(:player) { create(:player) }

    it "does not include session_id in as_json" do
      json = player.as_json
      # EXPECTATION: This should FAIL if default as_json includes all columns (which it does)
      expect(json.keys).not_to include("session_id")
    end
  end
end
