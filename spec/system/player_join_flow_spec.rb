require 'rails_helper'

RSpec.describe 'Player Join Flow', type: :system do
  let(:room) { create(:room) }

  it 'allows a player to join a game and become the host' do
    # 1. Visit the join path
    visit join_room_path(room)

    # 2. Check for the name form
    expect(page).to have_content("Join the Fun!")
    expect(page).to have_content(room.code)
    expect(page).to have_field("What's your name?")
    expect(page).to have_button('Join Game')
    screenshot_checkpoint("join_form")

    # 3. Fill in name and submit
    fill_in "What's your name?", with: 'Reynard Muldoon'
    click_on 'Join Game'
    expect(page).to have_current_path("/rooms/#{room.code}/hand", wait: 5)

    # 4. Assert player is created correctly
    player = Player.find_by(name: 'Reynard Muldoon')
    expect(player).not_to be_nil
    expect(player.room).to eq(room)

    # 5. Assert session_id is stored
    expect(player.session_id).not_to be_nil

    # 6. Claim Host manually
    click_on 'Claim Host'
    expect(page).to have_content("You're the host!")

    # 7. Assert player is the host
    room.reload
    expect(room.host).to eq(player)

    # 7. Assert redirection to lobby
    expect(page).to have_current_path(room_hand_path(room))
    expect(page).to have_content("Waiting for players to join...")
    expect(page).to have_content("Reynard Muldoon")
    screenshot_checkpoint("lobby_as_host")
  end

  it "shows host controls only to the host in a multi-player lobby" do
    # 1. A host joins the room in their own session
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "What's your name?", with: "Host Player"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("Host Player")
    end

    # 2. A second player joins in another session
    Capybara.using_session(:other) do
      visit join_room_path(room)
      fill_in "What's your name?", with: "Other Player"
      click_on "Join Game"
      expect(page).to have_content("Other Player")
    end

    # 3. Assert host's view: they should see the other player and the action buttons
    Capybara.using_session(:host) do
      expect(page).to have_content("Other Player")
      # The host should see the buttons next to the other player
      other_player = Player.find_by!(name: "Other Player")
      within "#player_#{other_player.id}" do
        expect(page).to have_button("Make Host")
        expect(page).to have_button("Kick")
      end
      screenshot_checkpoint("lobby_host_controls")
    end

    # 4. Assert other player's view: they should see the host, but no action buttons
    Capybara.using_session(:other) do
      expect(page).to have_content("Host Player")
      host_player = Player.find_by!(name: "Host Player")
      within "#player_#{host_player.id}" do
        # This is the key fix: we assert the buttons' container is in the DOM but hidden.
        expect(page).to have_selector("[data-player-card-target='actions']", visible: :hidden)
      end
      screenshot_checkpoint("lobby_non_host")
    end
  end
end
