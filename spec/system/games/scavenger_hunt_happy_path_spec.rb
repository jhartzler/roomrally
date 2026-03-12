require "rails_helper"

RSpec.describe "Scavenger Hunt Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Scavenger Hunt", user: nil) }

  before do
    pack = FactoryBot.create(:hunt_pack, :default)
    3.times do |i|
      FactoryBot.create(:hunt_prompt,
        hunt_pack: pack,
        body: "Test Prompt #{i + 1}",
        weight: 5,
        position: i)
    end
  end

  it "allows teams to submit photos, host curates, and reveals results" do
    # Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      fill_in "player[team_name]", with: "Team Alpha"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      fill_in "player[team_name]", with: "Team Beta"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # Host starts game
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"

      # Instructions screen
      expect(page).to have_content("Get ready!")
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click

      # Should see prompt list during hunting
      expect(page).to have_content("Test Prompt 1", wait: 5)
    end

    game = room.reload.current_game
    expect(game).to be_hunting

    # Simulate photo submissions via service (file upload through Capybara is brittle)
    host_player = room.players.find_by(name: "Host")
    alice = room.players.find_by(name: "Alice")
    instance1 = game.hunt_prompt_instances.first

    fixture = Rails.root.join("spec/fixtures/files/test_photo.jpg")
    Games::ScavengerHunt.submit_photo(
      game:,
      player: host_player,
      prompt_instance: instance1,
      media: { io: File.open(fixture), filename: "host_photo.jpg", content_type: "image/jpeg" }
    )
    Games::ScavengerHunt.submit_photo(
      game:,
      player: alice,
      prompt_instance: instance1,
      media: { io: File.open(fixture), filename: "alice_photo.jpg", content_type: "image/jpeg" }
    )

    # Host locks submissions and starts reveal
    Games::ScavengerHunt.lock_submissions_manually(game:)
    expect(game.reload).to be_times_up

    Games::ScavengerHunt.start_reveal(game:)
    expect(game.reload).to be_revealing

    # Show a submission on stage
    sub = instance1.hunt_submissions.first
    Games::ScavengerHunt.show_submission_on_stage(game:, submission: sub)

    # Start awards
    Games::ScavengerHunt.start_awards(game:)
    expect(game.reload).to be_awarding

    # Pick winner
    Games::ScavengerHunt.pick_winner(game:, prompt_instance: instance1, submission: sub)

    # Finish game
    Games::ScavengerHunt.finish_game(game:)
    expect(game.reload).to be_finished

    # Verify scores
    expect(host_player.reload.score).to eq(10) # 5 completion + 5 winner bonus
    expect(alice.reload.score).to eq(5) # 5 completion only

    # Verify finished state in browser
    Capybara.using_session(:host) do
      expect(page).to have_content("Game Over!", wait: 10)
    end
  end
end
