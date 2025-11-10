require 'rails_helper'

RSpec.describe 'Player Join Flow', type: :system do
  let(:room) { create(:room) }

  it 'allows a player to join a game and become the host' do
    # 1. Visit the join path
    visit join_room_path(room)

    # 2. Check for the name form
    expect(page).to have_content("Joining Room: #{room.code}")
    expect(page).to have_field('Name')
    expect(page).to have_button('Join')

    # 3. Fill in name and submit
    fill_in 'Name', with: 'Reynard Muldoon'
    click_on 'Join'
    expect(page).to have_current_path("/rooms/#{room.code}/hand", wait: 5)

    # 4. Assert player is created correctly
    player = Player.find_by(name: 'Reynard Muldoon')
    expect(player).not_to be_nil
    expect(player.room).to eq(room)

    # 5. Assert session_id is stored
    expect(player.session_id).not_to be_nil
    # Note: We can't directly test the server-side session here,
    # but we trust that setting it works. The reconnection flow will prove it.

    # 6. Assert player is the host
    room.reload
    expect(room.host).to eq(player)

    # 7. Assert redirection to lobby
    expect(page).to have_current_path(hand_room_path(room))
    expect(page).to have_content("Waiting for players...")
    expect(page).to have_content("Reynard Muldoon")
  end
end
