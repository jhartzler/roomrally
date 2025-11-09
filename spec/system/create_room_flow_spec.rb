require 'rails_helper'

RSpec.describe 'Room Creation Flow', type: :system do
  it 'displays the homepage elements correctly' do
    visit root_path
    expect(page).to have_button('Create Room')
    expect(page).to have_field('room_code', type: 'text')
    expect(page).to have_button('Join Room')
  end

  it 'allows a user to create a new room and redirects them to the join page' do
    visit root_path
    expect { click_on 'Create Room' }.to change(Room, :count).by(1)

    room = Room.last
    expect(page).to have_current_path("/rooms/#{room.code}/join")
    expect(page).to have_content("You are the host of room #{room.code}")
  end
end
