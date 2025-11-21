require 'rails_helper'

RSpec.describe "WriteAndVote Prompt Display", type: :system do
  # driven_by(:playwright) is configured in rails_helper.rb

  let(:room) { Room.create!(game_type: "Write And Vote") }
  let!(:player_1) { Player.create!(name: "Player 1", room:) }
  let!(:player_2) { Player.create!(name: "Player 2", room:) }
  let!(:player_3) { Player.create!(name: "Player 3", room:) }

  before do
    # Create master prompts
    3.times { |i| Prompt.create!(body: "Prompt #{i + 1}") }

    # Start the game
    Games::WriteAndVote.game_started(room)
    room.update!(status: "playing")
  end

  it "shows exactly two prompts to each player" do
    # Simulate Player 1 login/session (simplified for system test if auth is cookie-based,
    # but here we might need to just visit the room as the player if the app allows,
    # or rely on the fact that we can inspect the DOM)

    # Since we don't have a full auth system in the snippet, we'll assume we can visit a player's view
    # or we need to simulate the session.
    # Looking at the app, it seems to use sessions.
    # For this reproduction, let's try to visit the room and see if we can identify as a player
    # or if we need to go through the join flow.

    # Going through join flow to ensure we have a valid session
    # Login as Player 1 using the dev helper
    visit "/dev/testing/set_player_session/#{player_1.id}"

    # Visit the room hand
    visit "/rooms/#{room.code}/hand"

    # Wait for game to be in playing state (it already is)
    # We expect to see the hand screen

    expect(page).to have_css('[data-test-id="player-prompt"]', count: 2)
  end
end
