require 'rails_helper'

RSpec.describe "WriteAndVote Prompt Display", type: :system do
  # driven_by(:playwright) is configured in rails_helper.rb

  let(:room) { Room.create!(game_type: "Write And Vote") }
  let!(:alice) { Player.create!(name: "Alice", room:) }


  before do
    # Create master prompts
    3.times { |i| Prompt.create!(body: "Prompt #{i + 1}") }

    # Start the game
    Games::WriteAndVote.game_started(room)
    room.update!(status: "playing")
  end

  it "shows exactly two prompts to each player" do
    # Login as Player 1 using the dev helper
    visit "/dev/testing/set_player_session/#{alice.id}"

    # Visit the room hand
    visit "/rooms/#{room.code}/hand"



    expect(page).to have_css('[data-test-id="player-prompt"]', count: 2)
  end
end
