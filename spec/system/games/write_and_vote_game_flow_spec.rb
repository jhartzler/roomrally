require "rails_helper"

RSpec.describe "WriteAndVote game flow", type: :system do
  it "shows two prompts to the player when the game starts" do
    # 1. Setup
    # Create a room
    room = FactoryBot.create(:room, game_type: "Write And Vote")

    # Create other players in the background.
    # The host will be created via the UI flow.
    FactoryBot.create(:player, room:, name: "Player 2")
    FactoryBot.create(:player, room:, name: "Player 3")

    # 2. Action
    # A player joins and becomes the host.
    visit join_room_path(room)
    fill_in "player_name", with: "Host Player"
    click_on "Join Game"

    # After joining, they should be on their hand page.
    # The first player to join becomes the host.
    expect(page).to have_content("You're the host!")

    # The host clicks the "Start Game" button
    click_on "Start Game"

    # 3. Assertions
    # The page should show a notice that the game has started.
    expect(page).to have_content("Game started!")

    # Expect two prompt UI elements to be rendered
    expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
  end
end
