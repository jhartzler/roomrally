require "rails_helper"

RSpec.describe "Stage View Flow", type: :system do
  let!(:room) { Room.create!(game_type: "Write And Vote") }

  it "displays players as they join in real-time" do
    # open stage view in a new window/tab
    visit room_stage_path(room)

    expect(page).to have_content("Stage View")
    expect(page).to have_content(room.code)
    expect(page).to have_content("Join via your phone!")

    # Simulate player joining in another session
    using_session "player1" do
      visit join_room_path(room.code)
      fill_in "What's your name?", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Alice") # Player sees themselves
    end

    # Check stage view updates
    expect(page).to have_content("Alice")

    # Simulate another player joining
    using_session "player2" do
      visit join_room_path(room.code)
      fill_in "What's your name?", with: "Bob"
      click_on "Join Game"
    end

    expect(page).to have_content("Bob")
  end
end
