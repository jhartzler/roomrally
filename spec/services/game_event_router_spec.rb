# spec/services/game_event_router_spec.rb
require 'rails_helper'

RSpec.describe GameEventRouter do
  describe '.publish' do
    let(:room) { FactoryBot.build_stubbed(:room, game_type: 'TestGame') }
    let(:test_handler) do
      Class.new do
        def self.test_event(room, _arg1, _arg2); end
      end
    end

    before do
      described_class.register_game('TestGame', test_handler)
    end

    it 'calls the correct method on the registered handler' do
      allow(test_handler).to receive(:test_event)
      described_class.publish(:test_event, room, 'arg1', 'arg2')
      expect(test_handler).to have_received(:test_event).with(room, 'arg1', 'arg2')
    end

    it 'does not raise an error if the handler does not respond to the event' do
      expect { described_class.publish(:unknown_event, room) }.not_to raise_error
    end

    it 'does not raise an error if no handler is registered for the game type' do
      other_room = FactoryBot.build_stubbed(:room, game_type: 'OtherGame')
      expect { described_class.publish(:test_event, other_room) }.not_to raise_error
    end
  end
end
