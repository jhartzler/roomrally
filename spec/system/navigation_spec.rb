require 'rails_helper'

RSpec.describe 'Top navigation', type: :system do
  # PARKED: root redirects to the static parked page, which has no topnav —
  # the remaining pages (/play, /host) are still served, but the app is paused.
  it 'landing page redirects to the parked page' do
    visit root_path
    expect(page).to have_current_path("/parked.html")
    expect(page).to have_content("paused")
  end

  it '/play has nav links to host and join' do
    visit play_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
  end

  it '/host has nav links to host and join' do
    visit host_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
  end

  context 'when logged out' do
    it 'parked page is reachable and shows the contact form link' do
      visit root_path
      expect(page).to have_link(href: "https://forms.gle/xyHntsW9Kku1yaBw6")
    end
  end

  context 'when logged in' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'parked page is reachable' do
      visit root_path
      expect(page).to have_current_path("/parked.html")
      expect(page).to have_content("Comedy Clash")
    end
  end
end
