require "rails_helper"

RSpec.describe "Hand screen reconnect", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, user: nil) }

  it "reloads the page when tab has been hidden for more than 5 seconds" do
    visit join_room_path(room)
    fill_in "player[name]", with: "Alice"
    click_on "Join Game"
    expect(page).to have_current_path(room_hand_path(room))
    expect(page).to have_css("#hand_screen")

    # Simulate page going hidden
    page.execute_script(<<~JS)
      Object.defineProperty(document, 'hidden', { value: true, configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
    JS

    # Fast-forward the hiddenAt timestamp so the threshold is already exceeded
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller~="reconnect"]');
      const ctrl = window.Stimulus?.getControllerForElementAndIdentifier(el, 'reconnect');
      if (ctrl) ctrl.hiddenAt = Date.now() - 10_000;
    JS

    # Simulate page becoming visible — triggers Turbo.visit
    page.execute_script(<<~JS)
      Object.defineProperty(document, 'hidden', { value: false, configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
    JS

    # Page should have reloaded silently — still on the hand path with content intact
    expect(page).to have_css("#hand_screen")
    expect(page).to have_current_path(room_hand_path(room))
  end
end
