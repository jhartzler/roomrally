require 'rails_helper'

RSpec.describe 'Facilitator Backstage Real-time Updates', type: :system do
  let!(:facilitator) { create(:user) }
  let!(:room) { create(:room, user: facilitator) }
  # Ensure the room has a prompt pack
  let!(:prompt_pack) { create(:prompt_pack) }


  before do
    room.update(prompt_pack:)
  end

  it 'updates the player list when a player joins' do
    sign_in(facilitator)
    visit room_backstage_path(room.code)

    expect(page).to have_content("Backstage: #{room.code}")
    expect(page).to have_content("0 connected")

    # Simulate player joining in another session
    Capybara.using_session("player1") do
      visit join_room_path(room.code)
      find("input[name='player[name]']").set("Alice")
      click_on "Join Game"
    end

    # Facilitator should see the update without refreshing
    expect(page).to have_content("Alice")
    expect(page).to have_content("1 connected")

    # And empty message should disappear
    expect(page).not_to have_content("No players yet")
  end

  it 'shows submitted responses in the moderation queue' do
    # Ensure enough prompts
    create_list(:prompt, 3, prompt_pack:)

    # Bob joins via UI for session establishment (Login as Bob)
    Capybara.using_session("player_bob") do
      visit join_room_path(room.code)
      find("input[name='player[name]']").set("Bob")
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join")
    end

    create(:player, room:, name: "Charlie")

    room.update(status: "playing")
    Games::WriteAndVote.game_started(room:)

    sign_in(facilitator)
    visit room_backstage_path(room.code)

    # Wait for websocket connection
    expect(page).to have_content("Backstage: #{room.code}")

    # We need to ensure the view sees the "Game in Progress" state
    expect(page).to have_content("Game in Progress")
    expect(page).to have_content("Moderation Queue")
    expect(page).to have_selector("#moderation-queue")

    # Simulate player submitting response
    Capybara.using_session("player_bob") do
      # We just visit the hand path which should now be active
      # Since we are already logged in via UI
      visit room_hand_path(room.code)

      within first("[data-test-id='player-prompt']") do
        find("textarea[name='response[body]']").set("Funny Answer")
        click_on "Submit"
      end
    end

    # Facilitator should see the response
    expect(page).to have_content("Funny Answer")
    expect(page).to have_content("by Bob")

    # Rejection flow
    # Click summary to open details
    find("summary", text: "Reject").click
    fill_in "rejection_reason", with: "Too inappropriate"
    click_on "Confirm Reject"

    expect(page).not_to have_content("Funny Answer")
    expect(page).to have_content("No active responses to moderate")

    # Verify player sees rejection reason
    Capybara.using_session("player_bob") do
      expect(page).to have_content("Moderator Rejected:")
      expect(page).to have_content("Too inappropriate")

      # Resubmit
      within first("[data-test-id='player-prompt']") do
        fill_in "response[body]", with: "Clean Answer"
        click_on "Resubmit"
      end
    end

    # Verify resubmission appears in backstage
    expect(page).to have_content("Clean Answer", wait: 5)
  end

  it 'clears the moderation queue when voting starts' do
    # Setup game with players
    create(:player, room:, name: "Bob")
    create(:player, room:, name: "Charlie")
    create(:player, room:, name: "Dave")
    create_list(:prompt, 3, prompt_pack:)

    room.update(status: "playing")
    Games::WriteAndVote.game_started(room:)
    game = room.current_game

    sign_in(facilitator)
    visit room_backstage_path(room.code)

    # Bob submits
    bob = room.players.find_by(name: "Bob")
    prompt_instance = game.prompt_instances.where(round: 1).first
    create(:response, player: bob, prompt_instance:, body: "Moderated Answer", status: "submitted")

    # Manually trigger broadcast for simulation or just reload page? Realtime spec should catch it.
    GameBroadcaster.broadcast_response_submitted(response: Response.last)

    expect(page).to have_content("Moderated Answer")

    # Trigger transition to voting (simulate all submitted)
    # We can just call the service method directly to simulate the condition
    Games::WriteAndVote.send(:transition_to_voting, game:)

    # Queue should clear
    expect(page).not_to have_content("Moderated Answer")
    expect(page).to have_content("No active responses to moderate")
  end
end
