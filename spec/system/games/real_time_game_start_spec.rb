require 'rails_helper'

RSpec.describe "Real-time game start", type: :system do
  it "updates the screen for all players when the host starts the game" do
    # 1. Setup
    room = FactoryBot.create(:room, game_type: "Write And Vote")
    FactoryBot.create_list(:prompt, 5)

    # 2. Action
    # The host player joins the game
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # The other player joins the game
    Capybara.using_session(:other) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Other Player"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
    end

    # The host starts the game
    Capybara.using_session(:host) do
      click_on "Start Game"
      expect(page).to have_content("Game started!")
    end

    # 3. Assertions
    # The other player's screen should be updated
    Capybara.using_session(:other) do
      expect(page).to have_content("Your Prompts")
    end
  end
end
