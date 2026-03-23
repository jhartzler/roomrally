require 'rails_helper'

RSpec.describe 'Room Creation Flow', type: :system do
  describe '/play' do
    it 'shows only the join form, not the create form' do
      visit play_path
      expect(page).to have_button('Join Room')
      expect(page).not_to have_button('Create Room')
    end
  end

  describe '/host' do
    it 'shows the create room form' do
      visit host_path
      expect(page).to have_button('Create Room')
    end

    it 'creates a room and redirects to stage (desktop)' do
      visit host_path
      click_on 'Create Room'
      expect(page).to have_current_path(/\/rooms\/[A-Z0-9]{4}\/stage/, wait: 5)
      room_code = page.current_path.split('/')[2]
      room = Room.find_by!(code: room_code)
      expect(page).to have_content(room.code)
      expect(page).to have_selector('#stage_content')
    end
  end
end
