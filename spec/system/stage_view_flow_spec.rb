require "rails_helper"

RSpec.describe "Stage View Flow", type: :system do
  let!(:room) { Room.create!(game_type: "Write And Vote") }

  it "displays players as they join in real-time" do
    # open stage view in a new window/tab
    visit room_stage_path(room)

    expect(page).to have_content("ComedyClash") # default display name
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

    # Simulate host kicking a player
    using_session "player1" do
      if page.has_button?("Claim Host")
        click_on "Claim Host"
        expect(page).to have_content("You are now the host!")
      end

      # Find Bob's card and kick him
      bob = Player.find_by(name: "Bob")
      # Find Bob's card and hover it to reveal actions
      find("#player_#{bob.id}").hover
      within "#player_#{bob.id}" do
        accept_confirm do
          click_on "Kick"
        end
      end
    end

    # Verify Bob is removed from Stage View
    expect(page).to have_no_content("Bob")
  end
end
