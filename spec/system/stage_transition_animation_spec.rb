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
    FactoryBot.create(:player, room:, name: "Bob") # third player needed for minimum

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

    # Trigger a real phase transition: answering -> reviewing
    Games::SpeedTrivia.close_round(game: game.reload)

    # The stage should transition to reviewing with the animation class
    expect(page).to have_css("#stage_reviewing", wait: 5)
    expect(page).to have_css("#stage_reviewing.animate-fade-in")
  end

  it "does not re-add animate-fade-in when stage content is morphed within the same phase" do
    host_player = FactoryBot.create(:player, room:, name: "Host")
    room.update!(host: host_player)
    player2 = FactoryBot.create(:player, room:, name: "Alice")
    FactoryBot.create(:player, room:, name: "Bob") # third player needed for minimum

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
