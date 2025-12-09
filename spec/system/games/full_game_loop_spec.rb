require 'rails_helper'

RSpec.describe "Full Game Loop", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote") }

  before do
    # Ensure we have enough prompts for the game logic
    FactoryBot.create_list(:prompt, 10)
  end

  # Disabling test due to ongoing bug in playwright capybara, see GH issue: https://github.com/YusukeIwaki/capybara-playwright-driver/issues/83
  # Cannot rely on playwright capybara for system specs until this is resolved
  it "allows a host and players to play through the Write and Vote game", skip: 'https://github.com/YusukeIwaki/capybara-playwright-driver/issues/83' do
    # 1. Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      # puts page.body # Debugging
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
      expect(page).to have_content("Host Player")

      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      expect(page).to have_button("Start Game")
    end

    # 2. Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Player 2")
      expect(page).to have_content("Waiting for players to join...")
    end

    # 3. Host sees Player 2 and starts game
    Capybara.using_session(:host) do
      expect(page).to have_content("Player 2")
      click_on "Start Game"
      expect(page).to have_content("Game started!")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # 4. Player 2 sees game started
    Capybara.using_session(:player2) do
      expect(page).to have_content("Your Prompts")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # 5. Host submits answers
    Capybara.using_session(:host) do
      host_player = Player.find_by(name: "Host Player")
      prompt_instance = host_player.responses.first.prompt_instance

      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "Host Answer 1"
        click_on "Submit"
      end
      expect(page).to have_content("Your answer has been submitted!")
      expect(page).not_to have_selector("#prompt-instance-#{prompt_instance.id} form")
    end

    # 6. Player 2 submits answers
    Capybara.using_session(:player2) do
      player2 = Player.find_by(name: "Player 2")
      prompt_instance = player2.responses.first.prompt_instance

      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "Player 2 Answer 1"
        click_on "Submit"
      end
      expect(page).to have_content("Your answer has been submitted!")

      # Submit second answer
      prompt_instance_2 = player2.responses.last.prompt_instance
      within "#prompt-instance-#{prompt_instance_2.id}" do
        fill_in "response[body]", with: "Player 2 Answer 2"
        click_on "Submit"
      end
    end

    # 7. Host submits second answer -> Triggers Voting
    Capybara.using_session(:host) do
      host_player = Player.find_by(name: "Host Player")
      prompt_instance_2 = host_player.responses.last.prompt_instance

      within "#prompt-instance-#{prompt_instance_2.id}" do
        fill_in "response[body]", with: "Host Answer 2"
        click_on "Submit"
      end

      # Should transition to voting screen
      # Should transition to voting screen
      expect(page).to have_content("Vote for the best answer!", wait: 10)
      expect(page).to have_button("Vote", count: 2)
    end

    # 8. Player 2 sees voting screen
    Capybara.using_session(:player2) do
      visit hand_room_path(room.code) # Force reload to verify server state
      expect(page).to have_content("Vote for the best answer!")
      expect(page).to have_button("Vote", count: 2)

      # Vote for first option (Host Answer 1)
      # Find the button next to "Host Answer 1"
      # The structure is: button, then div with text.
      # We can find the div with text, then find the sibling button?
      # Or easier: just click the button inside the response card that contains the text.
      find(".response-card", text: "Host Answer 1").click_button("Vote")
      expect(page).to have_content("Waiting for other players...")
    end

    # 9. Host votes -> Triggers next prompt
    Capybara.using_session(:host) do
      host_render_time = find(".voting-screen")["data-render-time"]

      # Host votes for Player 2 Answer 2 (which is for Prompt 0)
      find(".response-card", text: "Player 2 Answer 2").click_button("Vote")

      # Should move to next prompt (Round 1, Prompt 2)
      expect(page).to have_content("Prompt 2 /")
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{host_render_time}'])")
      expect(page).to have_button("Vote", count: 2)
    end

    player2_render_time = nil
    Capybara.using_session(:player2) do
      player2_render_time = find(".voting-screen")["data-render-time"]
    end

    Capybara.using_session(:host) do
      # Host votes for Player 2 Answer 1 (which is for Prompt 1)
      find(".response-card", text: "Player 2 Answer 1").click_button("Vote")
    end

    # 10. Player 2 votes on second prompt -> Triggers Round 2
    Capybara.using_session(:player2) do
      expect(page).to have_content("Prompt 2 /")
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{player2_render_time}'])")

      # Player 2 votes for Host Answer 2
      find(".response-card", text: "Host Answer 2").click_button("Vote")

      # Should move to Round 2 (Writing Phase)
      expect(page).to have_content("Your Prompts")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # 11. Complete Round 2 (Fast forward)
    # Both players submit answers for Round 2
    [ [ :host, "Host Player" ], [ :player2, "Player 2" ] ].each do |session, name|
      Capybara.using_session(session) do
        player = Player.find_by(name:)
        # Reload player to get new responses
        player.reload
        # Get the last 2 responses which are for Round 2
        responses = player.responses.order(:id).last(2)

          responses.each_with_index do |response, index|
            expect(page).to have_selector("#prompt-instance-#{response.prompt_instance_id}")
            within "#prompt-instance-#{response.prompt_instance_id}" do
              fill_in "response[body]", with: "#{name} Round 2 Answer #{index + 1}"
              click_on "Submit"
            end
          end
      end
    end

    # 12. Vote through Round 2
    # There are 2 prompts in Round 2.
    # Prompt 1
    player2_render_time = nil
    Capybara.using_session(:player2) do
      player2_render_time = find(".voting-screen")["data-render-time"]
    end

    Capybara.using_session(:host) do
      expect(page).to have_content("Vote for the best answer!")
      # Host votes for Player 2 Round 2 Answer 2 (Prompt 1)
      expect(page).to have_content("Player 2 Round 2 Answer 2")
      find(".response-card", text: "Player 2 Round 2 Answer 2").click_button("Vote")
    end

    Capybara.using_session(:player2) do
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{player2_render_time}'])")

      # Player 2 votes for Host Round 2 Answer 1 (Prompt 1)
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{player2_render_time}'])")
      expect(page).to have_content("Host Player Round 2 Answer 1")
      find(".response-card", text: "Host Player Round 2 Answer 1").click_button("Vote")
    end

    # Prompt 2
    Capybara.using_session(:player2) do
      player2_render_time = find(".voting-screen")["data-render-time"]
    end

    Capybara.using_session(:host) do
      expect(page).to have_content("Prompt 2 /")
      # Host votes for Player 2 Round 2 Answer 1 (Prompt 2)
      expect(page).to have_content("Player 2 Round 2 Answer 1")
      find(".response-card", text: "Player 2 Round 2 Answer 1").click_button("Vote")
    end

    Capybara.using_session(:player2) do
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{player2_render_time}'])")

      # Player 2 votes for Host Round 2 Answer 2 (Prompt 2)
      expect(page).to have_selector(".voting-screen:not([data-render-time='#{player2_render_time}'])")
      expect(page).to have_content("Host Player Round 2 Answer 2")
      find(".response-card", text: "Host Player Round 2 Answer 2").click_button("Vote")

      # Game should be finished
      # Game should be finished
      expect(page).to have_content("Game Over!")
      expect(page).to have_content("Thanks for playing!")

      # Verify Scores (Both got 4 votes total across 2 rounds = 2000 points)
      expect(page).to have_content("Host Player")
      expect(page).to have_content("Player 2")
      expect(page).to have_content("2000 Points", count: 2)

      expect(page).to have_link("Back to Home", href: root_path)
    end
  end
end
