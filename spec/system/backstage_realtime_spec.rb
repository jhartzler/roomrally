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
    screenshot_checkpoint("backstage_empty")

    # Simulate player joining in another session
    Capybara.using_session("player1") do
      visit join_room_path(room.code)
      find("input[name='player[name]']").set("Alice")
      click_on "Join Game"
    end

    # Facilitator should see the update without refreshing
    expect(page).to have_content("Alice")
    expect(page).to have_content("1 connected")
    screenshot_checkpoint("backstage_with_players")

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
    Games::WriteAndVote.game_started(room:, show_instructions: false)

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

      within first('form[action^="/responses"]') do
        fill_in "response[body]", with: "Funny Answer"
        click_on "Submit Response"
      end
    end

    # Facilitator should see the response
    expect(page).to have_content("Funny Answer")
    expect(page).to have_content("BOB")
    screenshot_checkpoint("backstage_moderation_queue")

    # Rejection flow
    # Click Reject button to open modal (simulated by finding the button)
    # Since we replaced the details/summary with a direct button to a new path (likely handled by Turbo Frame),
    # we need to simulate the interaction compatible with the new partial.
    # The new partial uses: button_to "Reject", new_response_rejection_path...

    # We click the reject button for the response
    click_on "Reject"

    # This should open a modal or form. Assuming it renders the form visible:
    expect(page).to have_field("rejection_reason")
    fill_in "rejection_reason", with: "Too inappropriate"
    click_on "Reject Response"

    expect(page).not_to have_content("Funny Answer")
    expect(page).to have_content("No active responses to moderate")
    screenshot_checkpoint("backstage_after_rejection")

    # Verify player sees rejection reason
    Capybara.using_session("player_bob") do
      expect(page).to have_content("Let's try another answer")
      expect(page).to have_content("Too inappropriate")

      # Resubmit
      within find("[data-controller='character-counter']", text: "Let's try another answer") do
        fill_in "response[body]", with: "Clean Answer"
        click_on "Submit Revision"
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
    Games::WriteAndVote.game_started(room:, show_instructions: false)
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
