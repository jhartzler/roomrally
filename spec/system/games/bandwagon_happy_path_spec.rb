require "rails_helper"

RSpec.describe "Bandwagon happy path — majority mode", :js, type: :system do
  let!(:pack) do
    pack = PollPack.create!(name: "Test Pack", status: :live)
    pack.poll_questions.create!(body: "Dogs or cats?", options: [ "Dogs", "Cats" ], position: 0)
    pack.poll_questions.create!(body: "Pizza or tacos?", options: [ "Pizza", "Tacos" ], position: 1)
    pack
  end

  before { driven_by(:selenium_chrome_headless) }

  it "plays through a full majority-mode game" do
    room = create(:room, game_type: "Poll Game", user: nil)
    room.update!(poll_pack: pack)

    # Host joins and claims host via UI
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    Capybara.using_session(:player1) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player1"
      click_on "Join Game"
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player2"
      click_on "Join Game"
    end

    # Start game via service
    Games::Poll.game_started(
      room: room.reload,
      question_count: 2,
      scoring_mode: "majority",
      timer_enabled: false,
      show_instructions: true
    )

    # Host sees instructions and starts game
    Capybara.using_session(:host) do
      visit room_hand_path(room.code)
      expect(page).to have_content("Get ready!")
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_content(/get ready/i)
    end

    # Host starts first question
    Capybara.using_session(:host) do
      click_button "Start Question"
      expect(page).to have_content("Dogs or cats?")
    end

    # Players answer — both pick Dogs (option 0)
    Capybara.using_session(:player1) do
      visit room_hand_path(room.code)
      expect(page).to have_content("Dogs or cats?")
      find("[data-test-id='answer-option-0']").click
      expect(page).to have_content("Locked in!")
    end

    Capybara.using_session(:player2) do
      visit room_hand_path(room.code)
      expect(page).to have_content("Dogs or cats?")
      find("[data-test-id='answer-option-0']").click
      expect(page).to have_content("Locked in!")
    end

    # Host answers Cats (minority — option 1)
    Capybara.using_session(:host) do
      find("[data-test-id='answer-option-1']").click
      expect(page).to have_content("Locked in!")
    end

    # Host closes voting
    Capybara.using_session(:host) do
      click_button "Close Voting"
      expect(page).to have_content(/results/i)
    end

    # Majority players (Dogs) score, host (Cats) does not
    Capybara.using_session(:player1) do
      expect(page).to have_content("With the crowd!")
      expect(page).to have_content("+")
    end

    Capybara.using_session(:host) do
      expect(page).to have_content("Not the popular choice.")
    end

    # Verify DB — majority (Dogs) scored, minority (Cats) did not
    q1 = pack.poll_questions.find_by(position: 0)
    expect(PollAnswer.where(poll_question: q1, selected_option: "Dogs").sum(:points_awarded)).to be > 0
    expect(PollAnswer.where(poll_question: q1, selected_option: "Cats").sum(:points_awarded)).to eq(0)

    # Advance to Q2
    # "Next Question" advances immediately to answering (no waiting state between rounds)
    Capybara.using_session(:host) do
      click_button "Next Question"
      expect(page).to have_content("Pizza or tacos?")
    end

    Capybara.using_session(:player1) do
      expect(page).to have_content("Pizza or tacos?")
      find("[data-test-id='answer-option-0']").click
    end
    Capybara.using_session(:player2) do
      expect(page).to have_content("Pizza or tacos?")
      find("[data-test-id='answer-option-0']").click
    end
    Capybara.using_session(:host) do
      find("[data-test-id='answer-option-0']").click
      click_button "Close Voting"
      expect(page).to have_content(/results/i)
      click_button "Finish Game"
      expect(page).to have_content("That's a wrap!")
    end

    Capybara.using_session(:player1) do
      expect(page).to have_content("That's a wrap!")
    end
  end

  it "awards no points on a perfect tie" do
    room = create(:room, game_type: "Poll Game", user: nil)
    room.update!(poll_pack: pack)

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    Capybara.using_session(:player1) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player1"
      click_on "Join Game"
    end

    Games::Poll.game_started(
      room: room.reload,
      question_count: 1,
      scoring_mode: "majority",
      timer_enabled: false,
      show_instructions: false
    )

    Capybara.using_session(:host) do
      visit room_hand_path(room.code)
      expect(page).to have_content(/get ready/i)
      click_button "Start Question"
      expect(page).to have_content("Dogs or cats?")
      find("[data-test-id='answer-option-0']").click  # Dogs
    end

    Capybara.using_session(:player1) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-1']").click  # Cats
    end

    Capybara.using_session(:host) do
      click_button "Close Voting"
      expect(page).to have_content(/results/i)
    end

    q1 = pack.poll_questions.find_by(position: 0)
    expect(PollAnswer.where(poll_question: q1).sum(:points_awarded)).to eq(0)
  end
end
