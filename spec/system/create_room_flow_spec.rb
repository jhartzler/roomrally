require 'rails_helper'

RSpec.describe 'Room Creation Flow', type: :system do
  it 'displays the play page elements correctly' do
    visit play_path
    expect(page).to have_button('Create Room')
    expect(page).to have_field('room_code', type: 'text')
    expect(page).to have_button('Join Room')
    screenshot_checkpoint("play_page")
  end

  it 'allows a user to create a new room and redirects them to the join page' do
    visit play_path
    click_on 'Create Room'

    # Wait for the redirect to the join page and verify the path format
    expect(page).to have_current_path(/\/rooms\/[A-Z0-9]{4}\/stage/, wait: 5)

    # Extract the room code from the URL
    room_code = page.current_path.split('/')[2]
    room = Room.find_by!(code: room_code)

    # Now that we have the room, we can make specific assertions
    expect(page).to have_content(Room.default_display_name_for(Room::WRITE_AND_VOTE))
    expect(page).to have_content(room.code)
    # The stage lobby should be visible
    expect(page).to have_selector("#stage_content")
    screenshot_checkpoint("stage_after_create")
  end
end
