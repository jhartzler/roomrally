require "rails_helper"

RSpec.describe "WriteAndVote game flow", type: :system do
  it "creates prompt instances and responses and shows them to the player when the game starts" do
    # 1. Setup
    # Create a room
    room = FactoryBot.create(:room, game_type: "Write And Vote")

    # Create some master prompts
    FactoryBot.create(:prompt, body: "Master Prompt 1")
    FactoryBot.create(:prompt, body: "Master Prompt 2")
    FactoryBot.create(:prompt, body: "Master Prompt 3")

    # Create other players in the background.
    # The host will be created via the UI flow.
    FactoryBot.create(:player, room:, name: "Player 2")
    FactoryBot.create(:player, room:, name: "Player 3")

    # 2. Action
    # A player joins and becomes the host.
    visit join_room_path(room)
    fill_in "player[name]", with: "Host Player"
    click_on "Join Game"

    # After joining, they should be on their hand page.
    # The first player to join must claim host.
    click_on "Claim Host"
    expect(page).to have_content("You're the host!")

    # The host clicks the "Start Game" button
    click_on "Start Game"

    # 3. Assertions
    # The page should show a notice that the game has started.
    expect(page).to have_content("Game started!")

    # Check the database state
    expect(PromptInstance.count).to eq(3)
    expect(Response.count).to eq(6)

    host_player = Player.find_by(name: "Host Player")
    player2 = Player.find_by(name: "Player 2")
    player3 = Player.find_by(name: "Player 3")

    expect(host_player.responses.count).to eq(2)
    expect(player2.responses.count).to eq(2)
    expect(player3.responses.count).to eq(2)

    # Check that the host's prompts are displayed
    host_prompt_instances = host_player.responses.map { |r| r.prompt_instance.body }
    expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    expect(page).to have_content(host_prompt_instances[0])
    expect(page).to have_content(host_prompt_instances[1])
  end
end
