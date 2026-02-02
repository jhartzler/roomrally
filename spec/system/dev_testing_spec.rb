require 'rails_helper'

RSpec.describe "Dev testing", type: :system do
  it "creates a test game and displays the player links" do
    visit "/dev/testing"

    fill_in "num_players", with: "3"
    select "Write And Vote", from: "game_type"
    click_on "Create Test Game"

    expect(page).to have_content("Test Game Created")
    expect(page).to have_content("Room code:")
    expect(page).to have_content("Game type: Write And Vote")
    expect(page).to have_selector(".max-w-md div.space-y-4 > div.flex", count: 3)
  end
end
