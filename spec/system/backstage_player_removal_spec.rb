require 'rails_helper'

RSpec.describe "Backstage Player Removal", :js, type: :system do
  let!(:user) { FactoryBot.create(:user) }
  let!(:room) { FactoryBot.create(:room, user:) }

  it "removes player from backstage list when kicked" do
    # 1. User logs in and visits backstage
    visit root_path
    # Simulate login (dev/test environment might have a specific way, but standard is OmniAuth mock or session)
    # Using existing pattern if available, or just mocking session in controller which is hard in system spec.
    # Assuming 'user' being the room owner allows access if we are logged in.
    # We will fake login by using a backdoor or just checking if we can access directly if the app allows (it checks current_user).

    # Simulating login via simple backdoor if exists, or using OmniAuth mock.
    # Examining 'sessions_controller' or similar would help, but let's try standard potential dev-shim if available.
    # Looking at routes: get "/auth/:provider/callback", to: "sessions#omniauth"
    # We can mock OmniAuth.

    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user] if defined?(Devise)
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    # We probably need a streamlined way to login in specs.
    # Let's try to just visit backstage and see if it redirects or works if we stub something?
    # Actually, let's use the 'dev/testing' controller if it helps, or just manual logic.
    # Wait, 'dev_testing' routes exist: get "dev/testing", to: "dev_testing#index"

    # Let's try a simpler approach involves joining players and verifying they appear, then kicking one.
    # We need a 'host' or 'owner' to kick.

    # Let's use two players. One host, one target. Host kicks target.
    # Backstage is for 'user' (owner).
    # If we can't easily login as user, we can test "Host" kicking "Player" and checking the "Host" view (which also has a list).
    # But the bug was specifically about `backstage` list.

    # We must login as user.
    # Let's use `rack_session_access` if available, or just use the mock auth flow.
    # OmniAuth Mock:
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: user.uid,
      info: { email: user.email, name: user.name }
    })

    visit "/auth/google_oauth2/callback"

    visit room_backstage_path(room.code)
    expect(page).to have_content("Backstage")

    Capybara.using_session(:player) do
      visit join_room_path(room)
      fill_in "player[name]", with: "KickedPlayer"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players")
    end

    # Back in main session (Backstage)
    expect(page).to have_content("KickedPlayer", wait: 5)

    # Kick the player
    accept_confirm do
      find("li", text: "KickedPlayer").find_button("Kick").click
    end

    expect(page).to have_no_content("KickedPlayer", wait: 5)
  end
end
