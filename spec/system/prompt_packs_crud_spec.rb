require 'rails_helper'

RSpec.describe "PromptPack CRUD", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in(user)
  end

  describe "creating a prompt pack" do
    it "allows adding and removing prompts with dynamic count updates" do
      visit new_prompt_pack_path
      screenshot_checkpoint("new_prompt_pack")

      fill_in "Name", with: "My Fun Pack"

      # Initial state check - 1 prompt
      expect(page).to have_content("Supports up to 0 players")

      # Fill first prompt (which might be the only one or at bottom)
      find("textarea[name*='[body]']").set("Prompt 1")

      # Add second prompt (Prepended)
      click_button "Add Prompt"
      expect(page).to have_content("Supports up to 1 players")
      # New prompt is at the top
      all("textarea[name*='[body]']").first.set("Prompt 2")

      # Add third prompt (Prepended)
      click_button "Add Prompt"
      expect(page).to have_content("Supports up to 1 players")
      all("textarea[name*='[body]']").first.set("Prompt 3")

      # Remove one prompt (The bottom one, "Prompt 1")
      # Use JS click to bypass hover/visibility flake on CI
      wrapper = all(".prompt-field-wrapper").last
      button = wrapper.find("button[data-action='content-editor#removePrompt']", visible: :all)
      page.execute_script("arguments[0].click();", button)
      expect(page).to have_content("Supports up to 1 players")

      screenshot_checkpoint("new_prompt_pack_filled")
      click_button "Save Pack"

      expect(page).to have_content("Prompt pack created successfully")
      expect(page).to have_content("My Fun Pack")
      # We have 2 prompts left ("Prompt 3", "Prompt 2") -> 1 Player (ratio 2)
      expect(page).to have_content("1 Players")
      screenshot_checkpoint("prompt_pack_index_after_create")
    end
  end

  describe "editing a prompt pack" do
    let!(:pack) { create(:prompt_pack, user:, name: "Original Pack") }
    let!(:prompt) { create(:prompt, prompt_pack: pack, body: "Original Prompt") }

    it "allows updating the pack and modifying prompts" do
      visit prompt_packs_path
      click_link "Original Pack"
      click_link "Edit Pack"

      expect(page).to have_field("Name", with: pack.name)
      expect(page).to have_content("Supports up to 0 players")
      expect(page).to have_field(with: prompt.body)
      screenshot_checkpoint("edit_prompt_pack")

      fill_in "Name", with: "Updated Pack"

      # Add a new prompt (Prepended)
      click_button "Add Prompt"
      all("textarea[name*='[body]']").first.set("New Prompt")
      expect(page).to have_content("Supports up to 1 players")

      click_button "Save Pack"

      expect(page).to have_content("Prompt pack updated successfully")
      expect(page).to have_content("Updated Pack")
      expect(page).to have_content("1 Players")
    end

    it "allows deleting the pack" do
      visit edit_prompt_pack_path(pack)

      accept_confirm do
        click_button "Delete Pack"
      end

      expect(page).to have_content("Prompt pack deleted")
      expect(page).not_to have_content("Original Pack")
      screenshot_checkpoint("prompt_pack_index_after_delete")
    end
  end
end
