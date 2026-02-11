require "rails_helper"

RSpec.describe "Prompt Packs UI", type: :system do
  let(:user) { create(:user) }
  let!(:user_pack) { create(:prompt_pack, user:, name: "My Cool Pack") }
  let!(:system_pack) { create(:prompt_pack, :global, name: "System Standard") }

  before do
    sign_in(user)
  end

  describe "Library (Index)" do
    before { visit prompt_packs_path }

    it "links system packs to the show page" do
      screenshot_checkpoint("prompt_pack_library")
      find("h3", text: "System Standard").click_link
      expect(page).to have_current_path(prompt_pack_path(system_pack))
      expect(page).to have_content("System Standard")
      expect(page).to have_content(/system pack/i)
      expect(page).not_to have_link("Edit Pack")
      screenshot_checkpoint("system_prompt_pack_show")
    end

    it "links user packs to the show page" do
      find("h3", text: "My Cool Pack").click_link
      expect(page).to have_current_path(prompt_pack_path(user_pack))
      expect(page).to have_content("My Cool Pack")
      expect(page).to have_link("Edit Pack")
      screenshot_checkpoint("user_prompt_pack_show")
    end

    it "allows clicking the edit button directly from the card" do
      # Find the card containing the pack name, then find the 'Edit' link within it
      within(find("div", text: "My Cool Pack", match: :first)) do
        click_link "Edit"
      end
      expect(page).to have_current_path(edit_prompt_pack_path(user_pack))
    end

    it "has a working dashboard link" do
      click_link "Dashboard"
      expect(page).to have_current_path(dashboard_path)
    end
  end

  describe "Show Page" do
    it "allows navigating back to library" do
      visit prompt_pack_path(user_pack)
      click_link "Back to Library"
      expect(page).to have_current_path(prompt_packs_path)
    end

    it "allows owner to edit their pack" do
      visit prompt_pack_path(user_pack)
      click_link "Edit Pack"
      expect(page).to have_current_path(edit_prompt_pack_path(user_pack))
    end
  end

  describe "Play page" do
    it "shows Go to Dashboard link when logged in" do
      visit play_path
      expect(page).to have_link("Go to Dashboard", href: dashboard_path)
      expect(page).not_to have_button("Sign in with Google")
      screenshot_checkpoint("play_page_logged_in")
    end
  end
end
