require "rails_helper"

# Regression test for a production bug (2026-02-22):
#
# WHAT BROKE: Players could see the "Vote for this answer" buttons but clicking
# them did not create any Vote records. The game was stuck in the voting phase.
#
# ROOT CAUSE: The vote-feedback Stimulus controller called `btn.disabled = true`
# synchronously inside the click event handler. The browser checks the submit
# button's disabled state AFTER event handlers run but BEFORE executing the
# form's activation behavior (submission). So the button was already disabled
# by the time the browser tried to submit the form — the submission never fired.
#
# MASKING FACTOR: The "Vote cast!" UI feedback was shown optimistically inside
# the same click handler, before any server round-trip. Users saw a success
# state even though the request was never sent.
#
# WHY DEV PLAYTEST DIDN'T CATCH IT: The Playtest service (Games::WriteAndVote::Playtest)
# bypasses the UI entirely and calls game service methods directly. Any bug that
# lives in browser-side JS or Turbo form submission will not be caught by the
# Playtest service. System specs that drive the actual UI are required for this
# class of failure.
#
# FIX: Moved `btn.disabled = true` into a setTimeout(..., 0) so it runs after
# the current event loop tick (after the form activation behavior fires).
RSpec.describe "Write and Vote - Voting", :js, type: :system do
  let!(:room) { create(:room, game_type: "Write And Vote", user: nil) }

  # Creates all three players in insertion order and returns the middle one (the
  # non-author voter for the first prompt). The ring assignment uses ascending ID
  # order: author_a (i=0) writes PI0+PI1, voter (i=1) writes PI1+PI2, author_b
  # (i=2) writes PI2+PI0. So PI0's authors are author_a + author_b, leaving voter
  # as the only player who can vote on it.
  #
  # All three must be created in the same let! (not split across let!/before) so
  # that RSpec evaluates them in guaranteed order before the before block runs.
  let!(:voter) do
    create(:player, name: "Author A", room:)
    v = create(:player, name: "Voter", room:)
    create(:player, name: "Author B", room:)
    v
  end

  before do
    default_pack = create(:prompt_pack, :default)
    create_list(:prompt, 5, prompt_pack: default_pack)

    # Advance to voting state via service calls (faster than full UI flow).
    # This mirrors the dev Playtest service path — but note that the Playtest
    # service does NOT exercise the browser vote submission path tested below.
    Games::WriteAndVote.game_started(room: room.reload, show_instructions: false)
    game = room.reload.current_game
    Games::WriteAndVote::Playtest.bot_act(game:, exclude_player: nil)
    game.reload

    raise "Setup failed: expected voting state, got: #{game.status}" unless game.voting?
  end

  it "clicking 'Vote for this answer' submits the form and creates a vote record" do
    game = room.reload.current_game
    first_prompt = game.current_round_prompts.order(:id).first
    author_ids = first_prompt.responses.pluck(:player_id)

    expect(author_ids).not_to include(voter.id),
      "Expected voter to be the non-author for the first prompt. " \
      "If this fails, the prompt assignment ring logic may have changed."

    Capybara.using_session(:voter) do
      # set_player_session sets the session cookie and redirects to the hand
      visit set_player_session_path(voter)

      expect(page).to have_content("Vote for the best answer!", wait: 5)
      expect(page).to have_button("Vote for this answer")

      expect {
        click_button "Vote for this answer", match: :first

        # After the voter casts a vote on PI0, the game advances to PI1 where the
        # voter IS an author. The server broadcasts the updated hand, switching the
        # screen to "Voting in Progress". Waiting for this confirms the server
        # processed the request before we assert Vote.count.
        expect(page).to have_content("Voting in Progress", wait: 5)
      }.to change(Vote, :count).by(1)
    end
  end
end
