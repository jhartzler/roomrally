require 'rails_helper'

RSpec.describe GameBroadcaster do
  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)
    allow(Rails.logger).to receive(:info)
  end

  describe '.broadcast_hand' do
    let(:room) { create(:room) }
    let(:first_player) { create(:player, room:) }
    let(:second_player) { create(:player, room:) }

    before do
      # Ensure players are created
      first_player
      second_player
    end

    it 'broadcasts a morph to the hand_screen for the first player' do
      described_class.broadcast_hand(room:)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        first_player, action: :update, attributes: { method: :morph }, target: "hand_screen", partial: "rooms/hand_screen_content",
        locals: { room:, player: first_player }
      )
    end

    it 'broadcasts a morph to the hand_screen for the second player' do
      described_class.broadcast_hand(room:)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        second_player, action: :update, attributes: { method: :morph }, target: "hand_screen", partial: "rooms/hand_screen_content",
        locals: { room:, player: second_player }
      )
    end

    it 'logs the broadcast event' do
      described_class.broadcast_hand(room:)
      expect(Rails.logger).to have_received(:info).with(hash_including(event: "broadcast_hand")).at_least(:once)
    end
  end

  describe '.broadcast_stage' do
    let(:game) { create(:write_and_vote_game, status: :writing) }
    let(:room) { create(:room, current_game: game, game_type: "Write And Vote") }

    it 'broadcasts a morph to the stage_content' do
      described_class.broadcast_stage(room:)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        room, action: :update, attributes: { method: :morph }, target: "stage_content", partial: "games/write_and_vote/stage_writing",
        locals: { room:, game: }
      )
    end

    it 'logs the broadcast event' do
      described_class.broadcast_stage(room:)
      expect(Rails.logger).to have_received(:info).with(hash_including(event: "broadcast_stage")).at_least(:once)
    end
  end

  # rubocop:disable RSpec/ExampleLength
  describe '.broadcast_player_joined' do
    let(:room) { create(:room) }
    let(:player) { create(:player, room:) }

    before do
       allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
       allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
       allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
       allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
    end

    it 'broadcasts append to player-list' do
      described_class.broadcast_player_joined(room:, player:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        room,
        target: "player-list",
        partial: "players/player",
        locals: { player: }
      )
    end

    it 'broadcasts prepend to stage_player_list' do
      described_class.broadcast_player_joined(room:, player:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        room,
        target: "stage_player_list",
        partial: "players/stage_player",
        locals: { player: }
      )
    end
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:disable RSpec/ExampleLength
  describe '.broadcast_stage_lobby' do
    let(:room) { create(:room) }

    it 'broadcasts the lobby partial to the stage_content target' do
      described_class.broadcast_stage_lobby(room:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        room,
        action: :update,
        attributes: { method: :morph },
        target: "stage_content",
        partial: "rooms/stage_lobby",
        locals: { room: }
      )
    end

    it 'logs the broadcast event' do
      described_class.broadcast_stage_lobby(room:)
      expect(Rails.logger).to have_received(:info).with(hash_including(event: "broadcast_stage_lobby"))
    end
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:disable RSpec/ExampleLength
  describe '.broadcast_player_left' do
    let(:room) { create(:room) }
    let(:player) { create(:player, room:) }

    before do
      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    end

    it 'broadcasts remove to player dom_id' do
      described_class.broadcast_player_left(room:, player:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to).with(
        room,
        target: ActionView::RecordIdentifier.dom_id(player)
      )
    end

    it 'broadcasts remove to stage_player_id' do
      described_class.broadcast_player_left(room:, player:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to).with(
        room,
        target: "stage_player_#{player.id}"
      )
    end
  end
  # rubocop:enable RSpec/ExampleLength
end
