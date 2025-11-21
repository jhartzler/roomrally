require 'rails_helper'

RSpec.describe "Joining a Room", type: :system do
  # driven_by(:playwright) is configured in rails_helper.rb


  it "allows a user to join an existing room" do
    room = Room.create!(game_type: "Write And Vote")


    visit root_path

    fill_in "Enter Room Code", with: room.code
    click_button "Join Room"

    expect(page).to have_current_path("/rooms/#{room.code}/join")
    expect(page).to have_content("Room Code")
    expect(page).to have_content(room.code)
  end
end
