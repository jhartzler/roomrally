require 'rails_helper'

RSpec.describe 'Top navigation', type: :system do
  it 'landing page has nav links to host and join' do
    visit root_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
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
    it 'landing page nav shows login button' do
      visit root_path
      within('nav[data-testid="topnav"]') do
        expect(page).to have_button('Login with Google')
      end
    end
  end

  context 'when logged in' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'landing page nav shows studio link' do
      visit root_path
      within('nav[data-testid="topnav"]') do
        expect(page).to have_link('Studio', href: dashboard_path)
      end
    end
  end
end
