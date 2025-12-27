require 'rails_helper'

RSpec.describe "Round Timer Integration", :js, type: :system do
  include ActiveSupport::Testing::TimeHelpers

  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote") }

  before do
    # Ensure default pack exists
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 10, prompt_pack: default_pack)

    # Create Host and enough players to start game
    FactoryBot.create(:player, room:, name: "Host")
    FactoryBot.create_list(:player, 2, room:)

    # Ensure no pre-assigned host so we can claim it
    room.update!(host: nil)
  end

  it "auto-advances the game when time expires" do
    # 1. Start Game
    Capybara.using_session("host") do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("Game Settings")
      check "Enable Timer"
      click_on "Start Game"

      expect(page).to have_content("Time Left")
      expect(page).to have_content(/\d+s/) # Visual countdown check
    end

    # 2. Verify DB state
    game = room.reload.current_game
    expect(game.round_ends_at).to be_present
    expect(game.status).to eq("writing")

    # 3. Simulate Timeout
    # We can't wait 30s in test. We will manually trigger the job or time travel.
    # Time travel is tricky with JS but good for DB checks.
    # Job triggering is most reliable for logic verification.

    # Fast forward time for the backend
    travel 31.seconds do
      GameTimerJob.perform_now(game, 1)
    end

    # 4. Verify Advance
    game.reload
    expect(game.status).to eq("voting")

    # 5. Verify Voting Timer Started
    Capybara.using_session("host") do
      expect(page).to have_content("Time Left")
    end
    expect(game.round_ends_at).to be > Time.current

    # 6. Verify Auto-Fill
    # Players didn't submit anything, so responses should be "Ran out of time!"
    expect(Response.where(body: "Ran out of time!").count).to be > 0

    # 7. Verify Voting Timeout
    expect(game.current_prompt_index).to eq(0)
    travel 31.seconds do
      GameTimerJob.perform_now(game, 1, 0) # step_number = 0
    end

    game.reload
    expect(game.current_prompt_index).to eq(1) # Should advance to next prompt
    expect(game.round_ends_at).to be > Time.current # New timer started
  end

  it "allows host to disable timer" do
    Capybara.using_session("host") do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("Game Settings")
      uncheck "Enable Timer"
      click_on "Start Game"

      expect(page).to have_content("Write your best answer...")
      expect(page).not_to have_content("Time Left")
    end

    game = room.reload.current_game
    expect(game.timer_enabled).to be false
    expect(game.round_ends_at).to be_nil
  end

  it "allows host to configure timer duration" do
    Capybara.using_session("host") do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("Game Settings")
      check "Enable Timer"
      fill_in "Seconds per round", with: "45"
      click_on "Start Game"

      expect(page).to have_content("Time Left")
    end

    game = room.reload.current_game
    expect(game.timer_enabled).to be true
    expect(game.timer_increment).to eq(45)
    expect(game.timer_duration).to eq(45)
  end
end
