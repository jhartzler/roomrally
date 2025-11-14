# spec/services/game_event_router_spec.rb
require 'rails_helper'

RSpec.describe GameEventRouter do
  let(:room) { FactoryBot.build_stubbed(:room, game_type: 'TestGame') }
  let(:test_handler) do
    Class.new do
      def self.game_started(room); end
      def self.some_other_event(room); end
    end
  end

  before do
    described_class.register_game('TestGame', test_handler)
  end

  it 'calls the correct method on the registered handler' do
    allow(test_handler).to receive(:game_started)
    described_class.game_started(room)
    expect(test_handler).to have_received(:game_started).with(room)
  end

  it 'does not raise an error if the handler does not respond to the event' do
    expect { described_class.unknown_event(room) }.not_to raise_error
  end

  it 'does not raise an error if no handler is registered for the game type' do
    other_room = FactoryBot.build_stubbed(:room, game_type: 'OtherGame')
    expect { described_class.game_started(other_room) }.not_to raise_error
  end

  it 'responds to any method' do
    expect(described_class).to respond_to(:any_event_name)
  end
end
