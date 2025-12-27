require 'rails_helper'

RSpec.describe "Admin Buttons Visibility", :js, type: :system do
  let!(:room) { Room.create!(game_type: "Write And Vote") }

  it "shows admin buttons only to the host" do
    # 1. Player 1 joins
    Capybara.using_session(:player1) do
      visit join_room_path(room)
      fill_in "player_name", with: "Player 1"
      click_on "Join Game"
      expect(page).to have_content("Player 1")

      # Should see "Claim Host" button (since auto-claim is removed)
      expect(page).to have_button("Claim Host")

      # Should NOT see admin buttons yet (no host)
      expect(page).not_to have_button("Make Host")
      expect(page).not_to have_button("Kick")
    end

    # 2. Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player_name", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Player 2")

      # Should see "Claim Host" button
      expect(page).to have_button("Claim Host")

      # Should NOT see admin buttons
      expect(page).not_to have_button("Make Host")
      expect(page).not_to have_button("Kick")
    end

    # 3. Player 1 claims host
    Capybara.using_session(:player1) do
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")

      # Should see admin buttons for Player 2
      # We need to find Player 2's card
      player2_card = find("#player_#{Player.find_by(name: 'Player 2').id}")
      within(player2_card) do
        expect(page).to have_button("Make Host")
        expect(page).to have_button("Kick")
      end

      # Should NOT see admin buttons for self (Player 1)
      player1_card = find("#player_#{Player.find_by(name: 'Player 1').id}")
      within(player1_card) do
        expect(page).not_to have_button("Make Host")
        expect(page).not_to have_button("Kick")
      end
    end

    # 4. Verify Player 2 view
    Capybara.using_session(:player2) do
      # Player 2 should see Player 1 is host
      expect(page).to have_content("Host") # Player 1 card has Host badge

      # Player 2 should NOT see admin buttons on any card
      expect(page).not_to have_button("Make Host")
      expect(page).not_to have_button("Kick")
    end
  end
end
