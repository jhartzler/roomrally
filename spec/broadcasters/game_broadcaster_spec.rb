require 'rails_helper'

RSpec.describe GameBroadcaster do
  describe '.broadcast_hand_screen' do
    let(:room) { create(:room) }
    let(:first_player) { create(:player, room:) }
    let(:second_player) { create(:player, room:) }

    before do
      # Ensure players are created
      first_player
      second_player
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
      allow(Rails.logger).to receive(:info)
    end

    it 'broadcasts an update to the hand_screen for the first player' do
      described_class.broadcast_hand_screen(room:)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
        first_player, target: "hand_screen", partial: "rooms/hand_screen_content",
        locals: { room:, player: first_player }
      )
    end

    it 'broadcasts an update to the hand_screen for the second player' do
      described_class.broadcast_hand_screen(room:)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
        second_player, target: "hand_screen", partial: "rooms/hand_screen_content",
        locals: { room:, player: second_player }
      )
    end

    it 'logs the broadcast event' do
      described_class.broadcast_hand_screen(room:)
      expect(Rails.logger).to have_received(:info).with(hash_including(event: "broadcast_hand_screen")).at_least(:once)
    end
  end
end
