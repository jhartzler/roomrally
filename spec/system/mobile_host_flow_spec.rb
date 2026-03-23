require "rails_helper"

RSpec.describe "Mobile Host Flow", type: :system do
  describe "stage URL banner in lobby" do
    it "shows the stage URL banner to the host" do
      room = FactoryBot.create(:room)
      host = FactoryBot.create(:player, room:, name: "HostPlayer")
      room.update!(host:)

      visit set_player_session_path(host)
      visit room_hand_path(room)
      expect(page).to have_content("Throw this up on a big screen")
      expect(page).to have_content(room.code)
      expect(page).to have_button("Copy Link")
    end

    it "does not show the banner to non-host players" do
      room = FactoryBot.create(:room)
      host = FactoryBot.create(:player, room:, name: "HostPlayer")
      player = FactoryBot.create(:player, room:, name: "RegularPlayer")
      room.update!(host:)

      visit set_player_session_path(player)
      visit room_hand_path(room)
      expect(page).not_to have_content("Throw this up on a big screen")
    end
  end
end
