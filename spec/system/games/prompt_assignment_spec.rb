require 'rails_helper'

RSpec.describe "Prompt assignment", type: :system do
  it "assigns the correct number of prompts to each player" do
    # 1. Setup
    room = FactoryBot.create(:room, game_type: "Write And Vote")
    FactoryBot.create_list(:prompt, 5)

    # 2. Action
    # The host player joins the game
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
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
    end

    # 3. Assertions
    # The host should see 2 prompts
    Capybara.using_session(:host) do
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # The other player should see 2 prompts
    Capybara.using_session(:other) do
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end
  end
end
