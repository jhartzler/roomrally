require 'rails_helper'

RSpec.describe "Launch Game from Prompt Pack", type: :system do
  let(:user) { create(:user) }
  let!(:prompt_pack) { create(:prompt_pack, user:, name: "Funny Pack") }

  before do
    driven_by(:selenium_chrome_headless)
    # Ensure we have enough prompts for a game (ratio 2 prompts per player, min 3 players -> 6 prompts)
    create_list(:prompt, 6, prompt_pack:)
    sign_in(user)
  end

  it "allows a user to launch a game from their prompt pack" do
    visit prompt_pack_path(prompt_pack)

    expect(page).to have_content("Funny Pack")
    expect(page).to have_content("3")
    expect(page).to have_content("PLAYERS")

    click_button "Play Pack"

    # Verify UI transition first (this forces Capybara to wait)
    expect(page).to have_content("Backstage")

    # Verify the room is created with the correct prompt pack
    room = Room.last
    expect(room).to be_present
    expect(room.prompt_pack).to eq(prompt_pack)
    expect(room.game_type).to eq("Write And Vote")
    expect(page).to have_current_path(room_backstage_path(room))
    expect(page).to have_content(room.code)
  end
end
