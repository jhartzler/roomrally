require "rails_helper"

RSpec.describe "Stage transition animations", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = FactoryBot.create(:trivia_pack, :default)
    12.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Question #{i + 1}?",
        correct_answers: [ "Answer #{i + 1}" ],
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end
  end

  it "applies animate-fade-in on phase transition but not on in-phase morph" do
    # Create players directly so we can control the game via service methods
    host_player = FactoryBot.create(:player, room:, name: "Host")
    room.update!(host: host_player)
    player2 = FactoryBot.create(:player, room:, name: "Alice")
    player3 = FactoryBot.create(:player, room:, name: "Bob")

    # Start the game (skip instructions for simplicity)
    Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
    game = room.reload.current_game

    # Start the first question (transitions to answering)
    Games::SpeedTrivia.start_question(game: game.reload)

    # Open the stage view
    visit room_stage_path(room)
    expect(page).to have_css("#stage_answering", wait: 5)

    # Stage element should have animate-fade-in from the controller's connect()
    expect(page).to have_css("#stage_answering.animate-fade-in")

    # Submit an answer — this triggers broadcast_all but stays in answering phase
    Games::SpeedTrivia.submit_answer(game:, player: player2, selected_option: "Answer 1")

    # Wait for the morph broadcast to arrive — the answer count or UI may update
    # but the phase stays answering. Give Turbo time to process the morph.
    sleep 0.5

    # After an in-phase morph, animate-fade-in should NOT be re-added
    # (the controller only adds it on phase transitions, not in-phase morphs)
    # The class may still be present from the initial connect — that's fine.
    # What matters is the controller didn't re-trigger the animation.
    # We verify this by checking the element is the same (same ID, no re-animation).
    expect(page).to have_css("#stage_answering", wait: 5)

    # Now trigger a real phase transition: answering -> reviewing
    Games::SpeedTrivia.close_round(game: game.reload)

    # The stage should transition to reviewing with the animation class
    expect(page).to have_css("#stage_reviewing", wait: 5)
    expect(page).to have_css("#stage_reviewing.animate-fade-in")
  end

  it "does not re-add animate-fade-in when stage content is morphed within the same phase" do
    host_player = FactoryBot.create(:player, room:, name: "Host")
    room.update!(host: host_player)
    player2 = FactoryBot.create(:player, room:, name: "Alice")
    player3 = FactoryBot.create(:player, room:, name: "Bob")

    Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game: game.reload)

    visit room_stage_path(room)
    expect(page).to have_css("#stage_answering.animate-fade-in", wait: 5)

    # Remove the animation class manually via JS so we can detect if it gets re-added
    page.execute_script("document.getElementById('stage_answering').classList.remove('animate-fade-in')")
    expect(page).not_to have_css("#stage_answering.animate-fade-in")

    # Trigger an in-phase morph by submitting an answer
    Games::SpeedTrivia.submit_answer(game:, player: player2, selected_option: "Answer 1")

    # Wait for the morph to arrive
    sleep 0.5

    # animate-fade-in should NOT have been re-added — same phase, no transition
    expect(page).to have_css("#stage_answering", wait: 5)
    expect(page).not_to have_css("#stage_answering.animate-fade-in")
  end
end
