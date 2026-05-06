require "rails_helper"

RSpec.describe "Bandwagon host_choose mode", :js, type: :system do
  let!(:pack) do
    pack = PollPack.create!(name: "Wedding Pack", status: :live)
    pack.poll_questions.create!(
      body: "Who takes longer to get ready?",
      options: [ "Alex", "Jordan" ],
      position: 0
    )
    pack
  end

  before { driven_by(:selenium_chrome_headless) }

  it "host reveals the answer and only matching players score" do
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

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player2"
      click_on "Join Game"
    end

    Games::Poll.game_started(
      room: room.reload,
      question_count: 1,
      scoring_mode: "host_choose",
      timer_enabled: false,
      show_instructions: false
    )

    Capybara.using_session(:host) do
      visit room_hand_path(room.code)
      expect(page).to have_content(/get ready/i)
      click_button "Start Question"
      expect(page).to have_content("Who takes longer to get ready?")
    end

    # p1 picks Alex (option 0), p2 picks Jordan (option 1)
    Capybara.using_session(:player1) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-0']").click  # Alex
      expect(page).to have_content("Locked in!")
    end

    Capybara.using_session(:player2) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-1']").click  # Jordan
      expect(page).to have_content("Locked in!")
    end

    # Host answers then closes voting
    Capybara.using_session(:host) do
      find("[data-test-id='answer-option-0']").click  # Alex
      click_button "Close Voting"
      expect(page).to have_content(/results/i)
      expect(page).to have_content("Pick the correct answer")
    end

    # Players wait for host
    Capybara.using_session(:player1) do
      expect(page).to have_content("Waiting")
    end

    # Host picks Jordan as the correct answer
    Capybara.using_session(:host) do
      click_button "✓ Jordan"
      expect(page).to have_content("Answer: Jordan")
    end

    # Verify scoring: Jordan pickers scored, Alex pickers did not
    q = pack.poll_questions.first
    expect(PollAnswer.where(poll_question: q, selected_option: "Alex").sum(:points_awarded)).to eq(0)
    expect(PollAnswer.where(poll_question: q, selected_option: "Jordan").sum(:points_awarded)).to be > 0

    Capybara.using_session(:player2) do
      expect(page).to have_content("That's the one!")
    end
  end
end
