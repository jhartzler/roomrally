require 'rails_helper'

RSpec.describe "Lobby", type: :system do
  it "only shows the 'Make Host' and 'Kick' buttons to the host" do
    # 1. Setup
    room = FactoryBot.create(:room, game_type: "Write And Vote")

    # 2. Action
    # The host visits the hand page
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
    end

    # The other player visits the hand page
    Capybara.using_session(:other) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Other Player"
      click_on "Join Game"
    end

    # 3. Assertions
    # The host should see the "Make Host" and "Kick" buttons for the other player
    Capybara.using_session(:host) do
      within "#player-list" do
        expect(page).to have_button("Make Host")
        expect(page).to have_button("Kick")
      end
    end

    # The other player should not see the "Make Host" and "Kick" buttons
    Capybara.using_session(:other) do
      within "#player-list" do
        expect(page).not_to have_button("Make Host")
        expect(page).not_to have_button("Kick")
      end
    end
  end
end
