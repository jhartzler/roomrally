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

      fill_in "Name", with: "My Fun Pack"

      # Initial state check - 1 prompt
      expect(page).to have_content("Supports up to 0 players")

      # Fill first prompt
      find("textarea[name*='[body]']").set("Prompt 1")

      # Add second prompt
      click_button "Add Prompt"
      expect(page).to have_content("Supports up to 1 players")
      all("textarea[name*='[body]']").last.set("Prompt 2")

      # Add third prompt
      click_button "Add Prompt"
      expect(page).to have_content("Supports up to 1 players")
      all("textarea[name*='[body]']").last.set("Prompt 3")

      # Remove one prompt
      # Hover to make delete button visible
      all(".prompt-field-wrapper").last.hover
      all("button[data-action='content-editor#removePrompt']").last.click
      expect(page).to have_content("Supports up to 1 players")

      click_button "Save Pack"

      expect(page).to have_content("Prompt pack created successfully")
      expect(page).to have_content("My Fun Pack")
      expect(page).to have_content("Supports 1 Players")
    end
  end

  describe "editing a prompt pack" do
    let!(:pack) { create(:prompt_pack, user:, name: "Original Pack") }
    let!(:prompt) { create(:prompt, prompt_pack: pack, body: "Original Prompt") }

    it "allows updating the pack and modifying prompts" do
      visit prompt_packs_path
      click_link "Original Pack" # Should go to edit based on our previous changes

      expect(page).to have_field("Name", with: pack.name)
      expect(page).to have_content("Supports up to 0 players")
      expect(page).to have_field(with: prompt.body)

      fill_in "Name", with: "Updated Pack"

      # Add a new prompt
      click_button "Add Prompt"
      all("textarea[name*='[body]']").last.set("New Prompt")
      expect(page).to have_content("Supports up to 1 players")

      click_button "Save Pack"

      expect(page).to have_content("Prompt pack updated successfully")
      expect(page).to have_content("Updated Pack")
      expect(page).to have_content("Supports 1 Players")
    end

    it "allows deleting the pack" do
      visit edit_prompt_pack_path(pack)

      accept_confirm do
        click_button "Delete Pack"
      end

      expect(page).to have_content("Prompt pack deleted")
      expect(page).not_to have_content("Original Pack")
    end
  end
end
