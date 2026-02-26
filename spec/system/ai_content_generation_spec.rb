require "rails_helper"

RSpec.describe "AI content generation", :js, type: :system do
  let(:user) { create(:user) }
  let(:pack) { create(:prompt_pack, user: user, name: "Test Pack") }

  let(:fake_items) { 10.times.map { |i| { "body" => "AI prompt number #{i}" } } }
  let(:fake_content) { { "items" => fake_items }.to_json }
  let(:fake_raw) { { "choices" => [ { "message" => { "content" => fake_content } } ] }.to_json }

  before do
    driven_by(:selenium_chrome_headless)
    allow(LlmClient).to receive(:generate).and_return(
      { success: true, content: fake_content, raw_response: fake_raw }
    )
    sign_in(user)
  end

  it "generates items and allows user to add selected ones to the pack" do
    visit edit_prompt_pack_path(pack)

    # Open the AI panel
    find("summary", text: "Generate with AI").click
    expect(page).to have_css("textarea[name='user_theme']")

    # Fill in theme and submit
    fill_in "user_theme", with: "90s movies"
    click_button "⚡ Generate 10 items"

    # Spinner appears
    expect(page).to have_text("Generating your content")

    # Run the job directly in test thread so stub is applied and broadcast fires
    ai_request = AiGenerationRequest.last
    AiGenerationJob.perform_now(ai_request.id)

    # Review section appears via Turbo Stream broadcast
    expect(page).to have_text("AI Generated Content")
    expect(page).to have_text("AI prompt number 0")
    expect(page).to have_css("input[type='checkbox']", count: 10)

    # Select only first two items
    all("input[type='checkbox']").each(&:uncheck)
    all("input[type='checkbox']").first(2).each(&:check)

    click_button "Add Selected"

    # Redirected to edit page with new prompts
    expect(page).to have_current_path(edit_prompt_pack_path(pack))
    expect(page).to have_text("AI prompt number 0")
    expect(page).to have_text("AI prompt number 1")
    expect(pack.reload.prompts.count).to eq(2)
  end

  it "shows an error when AI response is invalid" do
    allow(LlmClient).to receive(:generate).and_return(
      { success: true, content: '{"items":[]}', raw_response: "{}" }
    )

    visit edit_prompt_pack_path(pack)

    find("summary", text: "Generate with AI").click
    fill_in "user_theme", with: "bad prompt"
    click_button "⚡ Generate 10 items"

    expect(page).to have_text("Generating your content")

    ai_request = AiGenerationRequest.last
    AiGenerationJob.perform_now(ai_request.id)

    expect(page).to have_text("couldn't generate a response")
  end

  it "disables the generate button when user is at the limit" do
    10.times do
      create(:ai_generation_request,
        user: user,
        counts_against_limit: true,
        status: :succeeded,
        created_at: 1.hour.ago)
    end

    visit edit_prompt_pack_path(pack)

    find("summary", text: "Generate with AI").click
    expect(page).to have_button("⚡ Generate 10 items", disabled: true)
    expect(page).to have_text("0 / 10 credits")
  end
end
