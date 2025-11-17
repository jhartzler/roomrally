require 'rails_helper'

RSpec.describe "Dev testing session", type: :system do
  it "correctly sets the session for all players" do
    visit "/dev/testing"

    fill_in "num_players", with: "5"
    select "Write And Vote", from: "game_type"
    click_on "Create Test Game"

    player_links = all("ul li a").map { |a| a["href"] }

    player_links.each_with_index do |link, i|
      Capybara.using_session("player_#{i + 1}") do
        visit link
        expect(page).not_to have_content("You need to join the room first.")
      end
    end
  end
end
