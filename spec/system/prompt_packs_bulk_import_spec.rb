require "rails_helper"

RSpec.describe "Prompt Pack Bulk Import", type: :system do
  let(:user) { create(:user) }
  let!(:pack) { create(:prompt_pack, user:, name: "Bulk Pack") }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in(user)
  end

  it "allows bulk importing prompts via text area" do
    visit edit_prompt_pack_path(pack)

    # Open the details element
    find("summary", text: "Bulk Import").click

    # Paste prompts
    prompts_text = <<~TEXT
      Why did the chicken cross the road?
      To get to the other side.
      Knock knock.
    TEXT

    find("textarea[data-content-editor-target='bulkText']").set(prompts_text)

    # Click Import
    click_button "Import Prompts"

    # Verify fields are created with correct values
    expect(page).to have_field(with: "Why did the chicken cross the road?")
    expect(page).to have_field(with: "To get to the other side.")
    expect(page).to have_field(with: "Knock knock.")

    # Verify input is cleared and details closed (optional but good UX)
    expect(find("textarea[placeholder*='Why did the chicken cross the road?']", visible: :all).value).to eq("")

    # Save check
    click_button "Save Pack"
    expect(page).to have_content("Prompt pack updated successfully")
    expect(page).to have_content("1 Players") # 3 prompts / 2 = 1
  end
end
