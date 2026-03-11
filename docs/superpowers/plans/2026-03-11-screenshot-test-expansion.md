# Screenshot Test Expansion Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand visual regression screenshot coverage to all game views and add GIF animation capture for complex animations.

**Architecture:** Two changes: (1) expand `screenshot_coverage_spec.rb` with new describe blocks for Write and Vote (full cycle), Speed Trivia hand views, Category List hand views, and backstage during gameplay; (2) add `screenshot_animation` helper that rapid-captures PNGs and stitches via ffmpeg into GIFs, with the HTML report updated to display GIFs inline.

**Tech Stack:** RSpec, Capybara, Selenium Chrome, ffmpeg (already installed)

---

## File Structure

| File | Responsibility |
|------|---------------|
| Modify: `spec/support/screenshot_checkpoint.rb` | Add `screenshot_animation` helper alongside existing `screenshot_checkpoint` |
| Modify: `spec/system/screenshot_coverage_spec.rb` | Add ~25 new checkpoints across all game types + backstage |
| Modify: `lib/tasks/screenshots.rake` | Update report to display GIFs inline, add gif detection |

---

## Chunk 1: GIF Animation Helper

### Task 1: Add `screenshot_animation` helper to support module

**Files:**
- Modify: `spec/support/screenshot_checkpoint.rb`

This helper captures rapid screenshots in a loop and stitches them into an animated GIF using ffmpeg. It's designed for targeted animation captures (2-4 seconds), not full test recordings.

- [ ] **Step 1: Add the `screenshot_animation` method**

Add to the `ScreenshotCheckpoint` module:

```ruby
# Captures rapid screenshots and stitches into animated GIF via ffmpeg.
# duration: seconds to capture (default 2)
# fps: frames per second (default 10)
def screenshot_animation(name, duration: 2, fps: 5)
  return unless ENV["SCREENSHOTS"] == "1"
  return unless system("which ffmpeg > /dev/null 2>&1")

  spec_description = sanitize_filename(self.class.description)
  session_name = Capybara.session_name.to_s
  gif_filename = "#{name}_#{session_name}.gif"

  dir = NEW_DIR.join(spec_description)
  FileUtils.mkdir_p(dir)

  frames_dir = Dir.mktmpdir("screenshot_anim")
  frame_count = duration * fps
  interval = 1.0 / fps

  frame_count.times do |i|
    frame_path = File.join(frames_dir, format("frame_%04d.png", i))
    page.save_screenshot(frame_path)
    sleep(interval) if i < frame_count - 1
  end

  output_path = dir.join(gif_filename).to_s

  # Two-pass ffmpeg: generate palette then encode GIF for best quality
  palette_path = File.join(frames_dir, "palette.png")
  system(
    "ffmpeg", "-y", "-framerate", fps.to_s,
    "-i", File.join(frames_dir, "frame_%04d.png"),
    "-vf", "palettegen=stats_mode=diff",
    palette_path,
    out: File::NULL, err: File::NULL
  )
  system(
    "ffmpeg", "-y", "-framerate", fps.to_s,
    "-i", File.join(frames_dir, "frame_%04d.png"),
    "-i", palette_path,
    "-lavfi", "paletteuse=dither=bayer:bayer_scale=5",
    output_path,
    out: File::NULL, err: File::NULL
  )
ensure
  FileUtils.rm_rf(frames_dir) if frames_dir
end
```

- [ ] **Step 2: Verify the helper loads without error**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb --dry-run`
Expected: 0 failures, specs listed but not executed

- [ ] **Step 3: Commit**

```bash
git add spec/support/screenshot_checkpoint.rb
git commit -m "feat: add screenshot_animation helper for GIF capture via ffmpeg"
```

### Task 2: Update rake report to handle GIF files

**Files:**
- Modify: `lib/tasks/screenshots.rake`

The report already uses `<img>` tags with base64 data URIs. GIFs work identically — we just need to detect `.gif` files alongside `.png` in the glob patterns, and use the correct MIME type in the data URI.

- [ ] **Step 1: Update glob patterns to include `.gif`**

In the `report` task, change both glob patterns from `"*.png"` to `"*.{png,gif}"`:

```ruby
# In the baseline scanning block:
Dir.glob(BASELINE_DIR.join("**", "*.{png,gif}")).each do |path|
  # ... existing code ...
end

# In the new screenshot scanning block:
Dir.glob(NEW_DIR.join("**", "*.{png,gif}")).each do |path|
  # ... existing code ...
end
```

Also in the `approve` task:
```ruby
Dir.glob(NEW_DIR.join("**", "*.{png,gif}")).each do |new_path|
  # ... existing code ...
end
```

- [ ] **Step 2: Update `image_data_uri` to detect MIME type and use file refs for GIFs**

GIFs can be several MB each; base64-encoding them bloats the HTML report. Use file:// URLs for GIFs, keep base64 for PNGs (which are smaller and self-contained):

```ruby
def image_data_uri(path)
  if path.end_with?(".gif")
    # GIFs are large — use file:// URL to avoid bloating the HTML
    "file://#{File.expand_path(path)}"
  else
    data = Base64.strict_encode64(File.binread(path))
    "data:image/png;base64,#{data}"
  end
end
```

- [ ] **Step 3: Add a visual badge for GIF entries in the report**

In `render_checkpoint`, add a small "GIF" indicator when the file is animated:

```ruby
# After the status badge, add:
gif_badge = row[:key].end_with?(".gif") ? '<span class="badge" style="background: #9b59b6; color: #fff;">GIF</span>' : ""
```

And include it in the header HTML:
```html
<span class="badge #{row[:status]}">#{row[:status]}</span>
#{gif_badge}
```

- [ ] **Step 4: Commit**

```bash
git add lib/tasks/screenshots.rake
git commit -m "feat: support GIF files in screenshot report and approval workflow"
```

---

## Chunk 2: Write and Vote Screenshot Coverage

### Task 3: Add Write and Vote stage views to coverage spec

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Add a new describe block after the existing Category List sections. This captures all 4 stage views (instructions, writing, voting, finished) in a single test that drives the game through its lifecycle.

- [ ] **Step 1: Add the Write and Vote stage views test**

Append to `screenshot_coverage_spec.rb` before the final `end`:

```ruby
describe "Write and Vote stage views" do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

  before do
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 10, prompt_pack: default_pack)
  end

  it "captures stage views through all phases" do
    stage_window = open_new_window
    within_window stage_window do
      visit room_stage_path(room)
      expect(page).to have_content(room.code)
    end

    # Join 3 players
    3.times do |i|
      using_session "player_#{i}" do
        visit join_room_path(room.code)
        fill_in "player[name]", with: "Player #{i}"
        click_on "Join Game"
      end
    end

    # Start game (instructions stage)
    using_session "player_0" do
      click_on "Claim Host"
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
    end

    within_window stage_window do
      expect(page).to have_content("How to Play", wait: 5)
      screenshot_checkpoint("stage_instructions")
    end

    # Advance past instructions (writing stage)
    using_session "player_0" do
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
    end

    within_window stage_window do
      expect(page).to have_content("Look at your device!", wait: 5)
      screenshot_checkpoint("stage_writing")
    end

    # Submit all responses to trigger voting
    game = room.reload.current_game
    game.prompt_instances.where(round: 1).each do |pi|
      pi.responses.update_all(body: "Funny Answer", status: "submitted")
    end
    Games::WriteAndVote.check_all_responses_submitted(game: game.reload)

    within_window stage_window do
      expect(page).to have_content("Cast your votes now!", wait: 5)
      screenshot_checkpoint("stage_voting")
    end

    # Finish game via AASM transition
    game.reload
    game.with_lock { game.finish_game! }
    game.calculate_scores!
    GameBroadcaster.broadcast_stage(room:)

    within_window stage_window do
      expect(page).to have_content("Game Over!", wait: 5)
      screenshot_checkpoint("stage_finished")
      screenshot_animation("stage_finished_celebration", duration: 3, fps: 5)
    end
  end
end
```

- [ ] **Step 2: Run the new test to verify it passes**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb -e "Write and Vote stage"`
Expected: 1 example, 0 failures

- [ ] **Step 3: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add Write and Vote stage screenshot coverage"
```

### Task 4: Add Write and Vote hand views to coverage spec

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Captures all hand view states: instructions (host), writing/prompt_screen, voting (voter with buttons), voting (author waiting), game_over.

- [ ] **Step 1: Add the Write and Vote hand views test**

```ruby
describe "Write and Vote hand views" do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

  before do
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 10, prompt_pack: default_pack)
  end

  it "captures hand views through all phases" do
    # Join players
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
    end

    # Start game — instructions hand view
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      click_on "Start Game"
      expect(page).to have_content("Get ready!", wait: 5)
      screenshot_checkpoint("hand_instructions_host")
      find("#start-from-instructions-btn").click
    end

    # Writing phase hand view
    Capybara.using_session(:host) do
      expect(page).to have_content("WRITE YOUR BEST ANSWER", wait: 10).or have_content("Write your best answer", wait: 10)
      screenshot_checkpoint("hand_writing")
    end

    Capybara.using_session(:player2) do
      expect(page).to have_content("WRITE YOUR BEST ANSWER", wait: 10).or have_content("Write your best answer", wait: 10)
      screenshot_checkpoint("hand_writing")
    end

    # Submit all responses to trigger voting
    game = room.reload.current_game
    game.prompt_instances.where(round: 1).each do |pi|
      pi.responses.update_all(body: "Hilarious Answer", status: "submitted")
    end
    Games::WriteAndVote.check_all_responses_submitted(game: game.reload)

    # Voting — player whose answer is NOT up sees vote buttons
    # Voting — player whose answer IS up sees "your answer is up for a vote"
    [:host, :player2, :player3].each do |session|
      Capybara.using_session(session) do
        unless page.has_content?("Vote for the best answer!", wait: 2)
          visit current_path
        end
        expect(page).to have_content("Vote for the best answer!", wait: 10)
                   .or have_content("Your answer is up for a vote!", wait: 10)

        if page.has_content?("Your answer is up for a vote!")
          screenshot_checkpoint("hand_voting_author_waiting")
        else
          screenshot_checkpoint("hand_voting_voter")
        end
      end
    end

    # Finish game via AASM transition
    game.reload
    game.with_lock { game.finish_game! }
    game.calculate_scores!
    GameBroadcaster.broadcast_all_hands(room:)

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_content(/game over/i, wait: 5)
      screenshot_checkpoint("hand_game_over")
    end
  end
end
```

- [ ] **Step 2: Run the new test**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb -e "Write and Vote hand"`
Expected: 1 example, 0 failures

- [ ] **Step 3: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add Write and Vote hand view screenshot coverage"
```

---

## Chunk 3: Speed Trivia and Category List Hand View Coverage

### Task 5: Add Speed Trivia hand views to coverage spec

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Captures all hand states: instructions, get_ready/waiting, answering (with options), locked_in, reviewing (correct answer), reviewing (wrong answer), game_over. Also captures score tally animation as GIF.

- [ ] **Step 1: Add the Speed Trivia hand views test**

```ruby
describe "Speed Trivia hand views" do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = FactoryBot.create(:trivia_pack, :default)
    12.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Test Question #{i + 1}?",
        correct_answers: ["Answer #{i + 1}"],
        options: ["Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C"])
    end
  end

  it "captures hand views through all phases" do
    # Join players
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
    end

    # Start game — instructions
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      click_on "Start Game"
      expect(page).to have_content("Get ready!", wait: 5)
      screenshot_checkpoint("hand_instructions_host")
      find("#start-from-instructions-btn").click
    end

    # Waiting / Get Ready
    Capybara.using_session(:host) do
      expect(page).to have_content("Get Ready!", wait: 5)
      screenshot_checkpoint("hand_get_ready_host")
    end

    Capybara.using_session(:player2) do
      expect(page).to have_content("Get Ready!", wait: 5)
      screenshot_checkpoint("hand_get_ready")
    end

    # Start question — answering
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)

    Capybara.using_session(:player2) do
      visit room_hand_path(room)
      expect(page).to have_selector('[data-test-id^="answer-option"]', minimum: 4, wait: 5)
      screenshot_checkpoint("hand_answering")
    end

    # Player answers — locked in
    Capybara.using_session(:player2) do
      find('[data-test-id="answer-option-0"]', match: :first).click
      expect(page).to have_content("Locked in!", wait: 5)
      screenshot_checkpoint("hand_locked_in")
    end

    # Submit remaining answers programmatically (player2 already answered via browser)
    tqi = game.reload.trivia_question_instances[game.current_question_index]

    host_player = room.players.find_by(name: "Host")
    bob = room.players.find_by(name: "Bob")

    # Host answers correctly
    TriviaAnswer.find_or_create_by!(player: host_player, trivia_question_instance: tqi) do |a|
      a.selected_option = tqi.correct_answers.first
      a.correct = true
      a.submitted_at = Time.current
    end
    # Bob answers wrong
    TriviaAnswer.find_or_create_by!(player: bob, trivia_question_instance: tqi) do |a|
      a.selected_option = "Wrong A"
      a.correct = false
      a.submitted_at = Time.current
    end

    Games::SpeedTrivia.close_round(game: game.reload)

    # Reviewing — correct answer
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_content("That's the one!", wait: 5)
      screenshot_checkpoint("hand_reviewing_correct")
      screenshot_animation("hand_score_tally", duration: 2, fps: 8)
    end

    # Reviewing — wrong answer
    Capybara.using_session(:player3) do
      visit room_hand_path(room)
      expect(page).to have_content("Not quite.", wait: 5)
      screenshot_checkpoint("hand_reviewing_wrong")
    end

    # Game over
    game.update!(current_question_index: game.trivia_question_instances.count - 1)
    Games::SpeedTrivia.next_question(game: game.reload)

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_content(/game over/i, wait: 5)
      screenshot_checkpoint("hand_game_over")
    end
  end
end
```

- [ ] **Step 2: Run the new test**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb -e "Speed Trivia hand"`
Expected: 1 example, 0 failures

- [ ] **Step 3: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add Speed Trivia hand view screenshot coverage"
```

### Task 6: Add Category List hand views to coverage spec

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Captures: instructions, filling (answer form), submitted/waiting, reviewing (host with moderation buttons), reviewing (non-host read-only), scoring (with leaderboard), game_over.

- [ ] **Step 1: Add the Category List hand views test**

```ruby
describe "Category List hand views" do
  let!(:room) { FactoryBot.create(:room, game_type: "Category List", user: nil) }

  before do
    default_pack = FactoryBot.create(:category_pack, :default)
    12.times do |i|
      FactoryBot.create(:category, name: "Category #{i + 1}", category_pack: default_pack)
    end
  end

  it "captures hand views through all phases" do
    # Join players
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
    end

    # Start game — instructions
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      click_on "Start Game"
      expect(page).to have_content("Get ready!", wait: 5)
      screenshot_checkpoint("hand_instructions_host")
      find("#start-from-instructions-btn").click
    end

    # Filling phase — answer form
    Capybara.using_session(:player2) do
      expect(page).to have_button("Submit Answers", wait: 10)
      screenshot_checkpoint("hand_filling")
    end

    # Submit answers for all players
    game = room.reload.current_game
    letter = game.current_letter
    room.players.each do |player|
      game.current_round_categories.each do |ci|
        CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
          answer.body = "#{letter}nswer"
        end
      end
    end
    game.with_lock { game.begin_review! if game.filling? }
    GameBroadcaster.broadcast_all_hands(room:)

    # Reviewing — host sees moderation controls
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_button("Reject", wait: 5)
      screenshot_checkpoint("hand_reviewing_host")
    end

    # Reviewing — non-host sees read-only answer list
    Capybara.using_session(:player2) do
      visit room_hand_path(room)
      expect(page).to have_content("Host is judging answers", wait: 5)
      screenshot_checkpoint("hand_reviewing_player")
    end

    # Scoring
    Games::CategoryList.finish_review(game: game.reload)

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_content(/Round 1 Scores/i, wait: 5)
      screenshot_checkpoint("hand_scoring_host")
    end

    Capybara.using_session(:player2) do
      visit room_hand_path(room)
      expect(page).to have_content(/Round 1 Scores/i, wait: 5)
      screenshot_checkpoint("hand_scoring")
    end

    # Game over
    game.reload.update!(current_round: game.total_rounds)
    Games::CategoryList.next_round(game: game.reload)

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_content(/game over/i, wait: 5)
      screenshot_checkpoint("hand_game_over")
    end
  end
end
```

- [ ] **Step 2: Run the new test**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb -e "Category List hand"`
Expected: 1 example, 0 failures

- [ ] **Step 3: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add Category List hand view screenshot coverage"
```

---

## Chunk 4: Backstage Coverage and GIF Animation Checkpoints

### Task 7: Add backstage during gameplay screenshot

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Captures the backstage view during an active Write and Vote game with the moderation queue visible.

- [ ] **Step 1: Add backstage during gameplay test**

```ruby
describe "Backstage during gameplay" do
  let!(:facilitator) { FactoryBot.create(:user) }
  let!(:room) { FactoryBot.create(:room, user: facilitator, game_type: "Write And Vote") }
  let!(:prompt_pack) { FactoryBot.create(:prompt_pack, :default) }

  before do
    room.update!(prompt_pack:)
    FactoryBot.create_list(:prompt, 5, prompt_pack:)
  end

  it "captures backstage with game in progress" do
    # Join players via service (faster than UI for setup)
    player1 = FactoryBot.create(:player, room:, name: "Alice")
    player2 = FactoryBot.create(:player, room:, name: "Bob")
    player3 = FactoryBot.create(:player, room:, name: "Charlie")

    # Start game
    Games::WriteAndVote.game_started(room:, show_instructions: false)
    game = room.reload.current_game

    # Submit a response so moderation queue has content
    pi = game.prompt_instances.where(round: 1).first
    response = pi.responses.find_by(player: player1)
    response.update!(body: "A hilarious answer", status: "submitted") if response

    # Visit backstage as facilitator
    sign_in(facilitator)
    visit room_backstage_path(room.code)
    expect(page).to have_content("Backstage: #{room.code}")
    expect(page).to have_content("Playing")
    screenshot_checkpoint("backstage_game_in_progress")
  end
end
```

- [ ] **Step 2: Run the new test**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb -e "Backstage during gameplay"`
Expected: 1 example, 0 failures

- [ ] **Step 3: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add backstage gameplay screenshot coverage"
```

### Task 8: Add GIF animation checkpoints for complex animations

**Files:**
- Modify: `spec/system/screenshot_coverage_spec.rb`

Add `screenshot_animation` calls at key animation points:
- Speed Trivia stage: podium bonk animation (stage_reviewing, when leaderboard reshuffles)
- Write and Vote stage: celebration/confetti on game over (already added in Task 3)
- Speed Trivia hand: score tally counting up (already added in Task 5)

- [ ] **Step 1: Add GIF capture to Speed Trivia stage reviewing (podium animation)**

In the existing "Speed Trivia stage views" describe block, after the `screenshot_checkpoint("stage_reviewing")` line, add:

```ruby
screenshot_animation("stage_podium_animation", duration: 2, fps: 8)
```

- [ ] **Step 2: Add GIF capture to Speed Trivia stage finished**

In the existing "Speed Trivia stage views" describe block, after the `screenshot_checkpoint("stage_finished")` line, add:

```ruby
screenshot_animation("stage_finished_animation", duration: 2, fps: 8)
```

- [ ] **Step 3: Run the full coverage spec**

Run: `SCREENSHOTS=1 bin/rspec spec/system/screenshot_coverage_spec.rb`
Expected: All examples pass

- [ ] **Step 4: Commit**

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "feat: add GIF animation checkpoints for podium and celebration animations"
```

---

## Chunk 5: Final Verification and Cleanup

### Task 9: Run full screenshot capture and verify report

- [ ] **Step 1: Build Tailwind CSS for test environment**

Run: `RAILS_ENV=test bin/rails tailwindcss:build`
Expected: CSS compiled successfully

- [ ] **Step 2: Run the full screenshot capture**

Run: `rake screenshots:capture[spec/system/screenshot_coverage_spec.rb]`
Expected: All tests pass, screenshots saved to `tmp/screenshots_new/`

- [ ] **Step 3: Verify screenshots exist**

Run: `find tmp/screenshots_new -name "*.png" -o -name "*.gif" | wc -l`
Expected: ~45+ files (combination of PNGs and GIFs)

- [ ] **Step 4: Generate and review the report**

Run: `rake screenshots:report`
Expected: Report opens in browser with all screenshots and GIFs visible. GIFs should animate inline.

- [ ] **Step 5: Final commit with any adjustments**

If any test expectations needed tweaking during verification, commit the fixes:

```bash
git add spec/system/screenshot_coverage_spec.rb
git commit -m "fix: adjust screenshot coverage test expectations from verification run"
```

### Task 10: Create feature branch and PR

- [ ] **Step 1: Create branch and push**

```bash
git checkout -b feature/screenshot-test-expansion
git push -u origin feature/screenshot-test-expansion
```

- [ ] **Step 2: Create PR**

Title: "Expand screenshot coverage to all views + GIF animation capture"
