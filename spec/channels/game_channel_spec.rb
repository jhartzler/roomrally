require 'rails_helper'

RSpec.describe GameChannel, type: :channel do
  let(:room) { create(:room) }

  before do
    # In a real app, you'd have a current_player identified by the connection.
    # For this test, we can stub the connection object.
    stub_connection
  end

  it 'successfully subscribes to a stream when room is found' do
    subscribe(code: room.code)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(room)
  end

  it 'rejects the subscription when room is not found' do
    subscribe(code: 'INVALID')
    expect(subscription).to be_rejected
  end
end