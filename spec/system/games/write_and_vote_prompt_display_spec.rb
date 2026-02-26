require 'rails_helper'

RSpec.describe "WriteAndVote Prompt Display", type: :system do
  let(:room) { Room.create!(game_type: "Write And Vote") }
  let!(:alice) { Player.create!(name: "Alice", room:) }
  let!(:bob) { Player.create!(name: "Bob", room:) }

  before do
    default_pack = FactoryBot.create(:prompt_pack, :default)
    3.times { |i| Prompt.create!(body: "Prompt #{i + 1}", prompt_pack: default_pack) }

    Games::WriteAndVote.game_started(room:, show_instructions: false)
    room.update!(status: "playing")

    visit "/dev/testing/set_player_session/#{alice.id}"
    visit "/rooms/#{room.code}/hand"
  end

  it "shows exactly two prompts to each player" do
    expect(page).to have_css('[data-test-id="player-prompt"]', count: 2)
  end

  it "shows both prompt texts in the stepper without requiring scroll" do
    within('[data-test-id="prompt-stepper"]') do
      # Both prompt texts should be visible in the stepper
      expect(page).to have_content("Prompt 1")
      expect(page).to have_content("Prompt 2")

      # Stepper state labels should be visible (CSS text-transform: uppercase renders them as ACTIVE / UP NEXT)
      expect(page).to have_content("ACTIVE", count: 1)
      expect(page).to have_content("UP NEXT", count: 1)
    end

    # Old progress pill should be gone
    expect(page).not_to have_content("of 2")
  end
end
