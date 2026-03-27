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

  describe "full mobile host flow (starting from mobile host setup)" do
    it "user enters name, becomes host, sees banner on hand view" do
      room = FactoryBot.create(:room)

      visit room_mobile_host_path(room)

      expect(page).to have_content("You're Hosting!")
      fill_in "Enter your name", with: "PartyStarter"
      click_on "Let's Go!"

      expect(page).to have_current_path(room_hand_path(room))
      expect(page).to have_content("Throw this up on a big screen")
      expect(page).to have_content("PartyStarter")

      player = Player.find_by(name: "PartyStarter")
      expect(player).not_to be_nil
      expect(room.reload.host).to eq(player)
    end
  end

  describe "banner disappears when game starts" do
    it "hides the stage URL banner after game starts" do
      room = FactoryBot.create(:room, game_type: "Write And Vote")
      host = FactoryBot.create(:player, room:, name: "Host")
      FactoryBot.create(:player, room:, name: "Player2")
      FactoryBot.create(:player, room:, name: "Player3")
      room.update!(host:)

      default_pack = FactoryBot.create(:prompt_pack, :default)
      FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)

      visit set_player_session_path(host)
      visit room_hand_path(room)

      expect(page).to have_content("Throw this up on a big screen")

      click_on "Start Game"

      expect(page).not_to have_content("Throw this up on a big screen")
    end
  end

  describe "shortcode route" do
    it "redirects /:code to stage view" do
      room = FactoryBot.create(:room)
      visit "/#{room.code}"
      expect(page).to have_current_path(room_stage_path(room))
    end

    it "handles lowercase codes" do
      room = FactoryBot.create(:room)
      visit "/#{room.code.downcase}"
      expect(page).to have_current_path(room_stage_path(room))
    end
  end
end
