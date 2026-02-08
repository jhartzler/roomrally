require 'rails_helper'

RSpec.describe "Dev testing session", type: :system do
  it "correctly sets the session for all players" do
    visit "/dev/testing"

    fill_in "num_players", with: "3"
    select "Write And Vote", from: "game_type"
    click_on "Create Test Game"

    # Find all "Open Hand" links from the player list
    hand_links = all("a", text: "Open Hand").map { |a| a["href"] }
    expect(hand_links.length).to eq(3)

    hand_links.each_with_index do |link, i|
      Capybara.using_session("player_#{i + 1}") do
        visit link
        expect(page).not_to have_content("You need to join the room first.")
      end
    end
  end
end
