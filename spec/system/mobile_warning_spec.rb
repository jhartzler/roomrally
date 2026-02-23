require 'rails_helper'

RSpec.describe 'Mobile warning modal on /host', type: :system, js: true do
  let(:mobile_size) { [390, 844] }   # iPhone 14 viewport
  let(:desktop_size) { [1280, 800] }

  describe 'logged-out user on mobile' do
    before { page.driver.browser.manage.window.resize_to(*mobile_size) }
    after  { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'shows the warning modal immediately' do
      visit host_path
      expect(page).to have_css('dialog[open]')
      expect(page).to have_text('are you joining or hosting')
    end

    it '"Go to Join Screen" navigates to /play' do
      visit host_path
      click_button 'Go to Join Screen'
      expect(page).to have_current_path(play_path)
    end

    it '"Continue Anyway" dismisses the modal and shows the form' do
      visit host_path
      click_button 'Continue Anyway'
      expect(page).not_to have_css('dialog[open]')
      expect(page).to have_button('Create Room')
    end
  end

  describe 'logged-out user on desktop' do
    before { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'does not show the modal' do
      visit host_path
      expect(page).not_to have_css('dialog[open]')
    end
  end

  describe 'logged-in user on mobile' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
      page.driver.browser.manage.window.resize_to(*mobile_size)
    end

    after { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'does not show the modal' do
      visit host_path
      expect(page).not_to have_css('dialog[open]')
    end
  end
end
