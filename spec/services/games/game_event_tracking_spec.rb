require "rails_helper"

RSpec.describe "GameEvent tracking in game services" do
  describe "SpeedTrivia" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let!(:players) { create_list(:player, 3, room:) }

    before do
      pack = create(:trivia_pack, :default)
      create_list(:trivia_question, 5, trivia_pack: pack)
      room.update!(trivia_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
      expect(event.metadata["game_type"]).to eq("Speed Trivia")
    end

    it "logs state_changed on start_from_instructions" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::SpeedTrivia.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("waiting")
    end

    it "logs state_changed on start_question" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
      game = room.reload.current_game

      expect {
        Games::SpeedTrivia.start_question(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("answering")
    end

    it "logs state_changed on close_round" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)

      expect {
        Games::SpeedTrivia.close_round(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("reviewing")
    end

    it "logs game_finished when last question reviewed" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false, question_count: 1)
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)
      Games::SpeedTrivia.close_round(game:)

      expect {
        Games::SpeedTrivia.next_question(game:)
      }.to change { GameEvent.where(event_name: "game_finished").count }.by(1)
    end
  end

  describe "WriteAndVote" do
    let(:room) { create(:room, game_type: "Write And Vote") }
    let!(:players) { create_list(:player, 3, room:) }

    before do
      pack = create(:prompt_pack, :default)
      create_list(:prompt, 3, prompt_pack: pack)
      room.update!(prompt_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
    end

    it "logs state_changed on start_from_instructions" do
      Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::WriteAndVote.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("writing")
    end
  end

  describe "CategoryList" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { create_list(:player, 3, room:) }

    before do
      pack = create(:category_pack, :default)
      create_list(:category, 10, category_pack: pack)
      room.update!(category_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
    end

    it "logs state_changed on start_from_instructions" do
      Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::CategoryList.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("filling")
    end
  end
end
