
require 'rails_helper'

RSpec.describe "Game Over Screen", type: :system do
  let(:room) { create(:room, game_type: "Write And Vote") }
  let(:game) { create(:write_and_vote_game, status: 'finished') }
  let(:winner) { create(:player, room:, name: "Winner", score: 2000) }
  let(:runner_up) { create(:player, room:, name: "Runner Up", score: 1000) }
  let(:loser) { create(:player, room:, name: "Loser", score: 500) }

  before do
    winner
    runner_up
    loser
    room.update!(current_game: game)
  end

  it "displays the leaderboard with correct scores" do
    visit room_hand_path(room.code)

    # Login as one of the players (simulation, since we visit hand_room_path directly usually requires session)
    # The app seems to use session_id cookies or similar.
    # Let's check how other tests populate session.
    # checking create_room_flow_spec.rb or similar...
    # The `room_hand_path` puts you in the lobby or hand screen.
    # Just simulating "viewing" the component might be easier if we render_inline in a ViewComponent test,
    # but this is a system test.

    # We need to simulate joining or having a session.
    # Let's simulate the host flow briefly or just manual session cookie if possible.
    # Actually, the full game loop uses `Capybara.using_session`.

    # Simpler: Just rely on the fact that if we go to join_room and join as "Winner", we should see the screen.

    visit join_room_path(room)
    fill_in "player[name]", with: "Winner"
    click_on "Join Game"

    # Current game is finished, so it should redirect/show the game over screen immediately?
    # Logic in RoomsController#show / Join?

    # If the game is already in progress/finished, joining might behave differently.
    # But let's assume valid re-entry.

    expect(page).to have_content("Game Over!")
    expect(page).to have_content("Grand Champion")

    within first(".bg-gradient-to-br") do # Winner card
      expect(page).to have_content("Winner")
      expect(page).to have_content("2000")
    end

    expect(page).to have_content("Runner Up")
    expect(page).to have_content("1000")
    screenshot_checkpoint("game_over_leaderboard")

    # Loser might not be shown if top 2 only? check implementation
    # Implementation:
    # <% sorted_players = room.players.order(score: :desc) %>
    # <% winner = sorted_players.first %>
    # <% runner_up = sorted_players.second %>
    # So only top 2 are shown.

    expect(page).not_to have_content("Loser")
    expect(page).not_to have_content("500 Points")
  end
end
