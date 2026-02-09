require 'rails_helper'

RSpec.describe "Dev testing", type: :system do
  it "creates a test game and displays the playtest dashboard" do
    visit "/dev/testing"

    fill_in "num_players", with: "3"
    select "Write And Vote", from: "game_type"
    click_on "Create Test Game"

    expect(page).to have_content("Write And Vote")
    expect(page).to have_content("lobby")
    expect(page).to have_content("Start Game")
    expect(page).to have_content("Player 1 (host)")
    expect(page).to have_content("Player 2")
    expect(page).to have_content("Player 3")
  end
end
