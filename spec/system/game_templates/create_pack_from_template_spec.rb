require 'rails_helper'

RSpec.describe "Create pack from template form", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in(user)
  end

  it "saves template state and returns with new trivia pack selected" do
    visit new_game_template_path

    # Fill in partial template state (use name attribute since label has no `for`)
    find('input[name="game_template[name]"]').fill_in with: "Friday Trivia Night"

    # Select Speed Trivia game type (radio is display:none, click the wrapping label)
    # Display name is "Think Fast" per Room::GAME_DISPLAY_NAMES
    find('label', text: 'Think Fast').click

    # Verify the trivia pack section is visible and the "Create" link appears
    expect(page).to have_text("Create a new trivia pack")

    # Click the link — should navigate to trivia pack creation
    click_link "Create a new trivia pack"

    expect(page).to have_current_path(%r{/trivia_packs/new})

    # Create a trivia pack (no questions required)
    fill_in "Name", with: "My Custom Quiz"
    click_button "Save Pack"

    # Should redirect back to the game template form
    expect(page).to have_current_path(%r{/game_templates/new})

    # Template name should be restored
    expect(find('input[name="game_template[name]"]').value).to eq("Friday Trivia Night")

    # Speed Trivia should still be selected (radio is display:none, use visible: false)
    expect(find('input[type=radio][value="Speed Trivia"]', visible: false)).to be_checked

    # New pack should be auto-selected in the trivia pack dropdown
    trivia_select = find("select[name='game_template[trivia_pack_id]']")
    expect(trivia_select.value).to eq(TriviaPack.last.id.to_s)
  end
end
