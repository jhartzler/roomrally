require "rails_helper"

RSpec.describe Games::CategoryList do
  let(:user) { create(:user) }
  let!(:default_pack) { create(:category_pack, :default) }
  let!(:categories) do
    10.times.map { |i| create(:category, name: "Category #{i}", category_pack: default_pack) }
  end

  describe ".game_started" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { 3.times.map { create(:player, room:) } }

    it "creates a game and sets up the first round" do
      described_class.game_started(room:)
      game = room.reload.current_game

      expect(game).to be_a(CategoryListGame)
      expect(game.current_round).to eq(1)
      expect(game.current_letter).to be_present
      expect(game.category_instances.where(round: 1).count).to eq(6)
    end

    it "skips instructions when show_instructions is false" do
      described_class.game_started(room:, show_instructions: false)
      game = room.reload.current_game

      expect(game).to be_filling
    end

    it "stays in instructions when show_instructions is true" do
      described_class.game_started(room:, show_instructions: true)
      game = room.reload.current_game

      expect(game).to be_instructions
    end

    it "uses custom total_rounds and categories_per_round" do
      described_class.game_started(room:, total_rounds: 5, categories_per_round: 4)
      game = room.reload.current_game

      expect(game.total_rounds).to eq(5)
      expect(game.categories_per_round).to eq(4)
      expect(game.category_instances.where(round: 1).count).to eq(4)
    end

    it "does not create a game if one already exists" do
      described_class.game_started(room:)
      described_class.game_started(room:)
      expect(CategoryListGame.count).to eq(1)
    end
  end

  describe ".finish_game!" do
    let(:room) { create(:room, game_type: "Category List", status: "playing") }
    let!(:players) { 3.times.map { create(:player, room:) } }

    before do
      room.update!(host: players.first)
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
      allow(GameBroadcaster).to receive(:broadcast_game_start)
      allow(GameBroadcaster).to receive(:broadcast_stage_lobby)
    end

    context "with scoreable data" do
      let(:game) do
        described_class.game_started(room:, show_instructions: false, categories_per_round: 2)
        room.reload.current_game
      end

      before do
        # Submit answers for all players on all categories
        game.current_round_categories.each do |ci|
          players.each do |player|
            described_class.submit_answers(
              game: game.reload,
              player:,
              answers_params: { ci.id.to_s => "Unique #{player.id} #{ci.id}" }
            )
          end
        end
      end

      it "finishes the game" do
        described_class.finish_game!(game: game.reload)
        expect(game.reload.status).to eq("finished")
      end

      it "finishes the room" do
        described_class.finish_game!(game: game.reload)
        expect(room.reload.status).to eq("finished")
      end

      it "calculates total scores" do
        described_class.finish_game!(game: game.reload)
        scored_players = room.players.active_players.where("score > 0")
        expect(scored_players).to exist
      end

      it "logs a game_finished event" do
        described_class.finish_game!(game: game.reload)
        event = GameEvent.find_by(eventable: game, event_name: "game_finished")
        expect(event).to be_present
        expect(event.metadata["details"]).to eq("ended by host")
      end
    end

    context "without scoreable data" do
      before do
        described_class.game_started(room:, show_instructions: true)
      end

      it "destroys the game" do
        game = room.reload.current_game
        expect { described_class.finish_game!(game:) }.to change(CategoryListGame, :count).by(-1)
      end

      it "resets room to lobby" do
        game = room.reload.current_game
        described_class.finish_game!(game:)
        expect(room.reload.status).to eq("lobby")
      end

      it "nils out current_game" do
        game = room.reload.current_game
        described_class.finish_game!(game:)
        expect(room.reload.current_game).to be_nil
      end

      it "broadcasts lobby state" do
        game = room.reload.current_game
        described_class.finish_game!(game:)
        expect(GameBroadcaster).to have_received(:broadcast_stage_lobby).with(room:).once
        expect(GameBroadcaster).to have_received(:broadcast_hand).with(room:).at_least(:once)
        expect(GameBroadcaster).to have_received(:broadcast_host_controls).with(room:).at_least(:once)
      end
    end
  end

  describe ".start_from_instructions" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { 3.times.map { create(:player, room:) } }

    before { described_class.game_started(room:) }

    it "transitions from instructions to filling" do
      game = room.reload.current_game
      described_class.start_from_instructions(game:)
      expect(game.reload).to be_filling
    end
  end

  describe ".submit_answers" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { 3.times.map { create(:player, room:) } }
    let(:game) do
      described_class.game_started(room:, show_instructions: false)
      room.reload.current_game
    end

    it "creates category answers for the player" do
      ci = game.current_round_categories.first
      described_class.submit_answers(
        game:,
        player: players.first,
        answers_params: { ci.id.to_s => "Apple" }
      )

      expect(CategoryAnswer.where(player: players.first, category_instance: ci).count).to eq(1)
      expect(CategoryAnswer.last.body).to eq("Apple")
    end

    it "transitions to reviewing when all players submit" do
      game.current_round_categories.each do |ci|
        players.each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { ci.id.to_s => "Answer" }
          )
        end
      end

      expect(game.reload).to be_reviewing
    end
  end

  describe ".finish_review" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { 3.times.map { create(:player, room:) } }
    let(:game) do
      described_class.game_started(room:, show_instructions: false)
      room.reload.current_game
    end

    before do
      # Submit all answers to transition to reviewing
      game.current_round_categories.each do |ci|
        players.each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { ci.id.to_s => "Answer #{player.id}" }
          )
        end
      end
      expect(game.reload).to be_reviewing
    end

    it "calculates scores and transitions to scoring" do
      described_class.finish_review(game: game.reload)
      expect(game.reload).to be_scoring
    end
  end

  describe ".next_round" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { 3.times.map { create(:player, room:) } }

    def play_through_round(game)
      game.current_round_categories.each do |ci|
        players.each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { ci.id.to_s => "Answer" }
          )
        end
      end
      described_class.finish_review(game: game.reload)
    end

    it "advances to next round when not the last round" do
      game_started = described_class.game_started(room:, show_instructions: false, total_rounds: 2)
      game = room.reload.current_game

      play_through_round(game)
      described_class.next_round(game: game.reload)

      expect(game.reload).to be_filling
      expect(game.current_round).to eq(2)
    end

    it "finishes the game on the last round" do
      room.start_game! # Transition room from lobby to playing
      described_class.game_started(room:, show_instructions: false, total_rounds: 1)
      game = room.reload.current_game

      play_through_round(game)
      described_class.next_round(game: game.reload)

      expect(game.reload).to be_finished
      expect(room.reload).to be_finished
    end
  end

  describe "scoring" do
    let(:room) { create(:room, game_type: "Category List") }
    let(:game) { room.reload.current_game }
    let!(:player1) { create(:player, room:) }
    let!(:player2) { create(:player, room:) }
    let!(:player3) { create(:player, room:) }

    before do
      described_class.game_started(room:, show_instructions: false, categories_per_round: 3)
    end


    it "awards 0 points for duplicate answers" do
      ci = game.current_round_categories.first

      # All players answer the same thing
      [ player1, player2, player3 ].each do |player|
        described_class.submit_answers(
          game: game.reload,
          player:,
          answers_params: { ci.id.to_s => "Same Answer" }
        )
      end

      # Submit remaining categories to complete the round
      game.current_round_categories.where.not(id: ci.id).each do |other_ci|
        [ player1, player2, player3 ].each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { other_ci.id.to_s => "Unique #{player.id} #{other_ci.id}" }
          )
        end
      end

      described_class.finish_review(game: game.reload)

      ci.category_answers.reload.each do |answer|
        expect(answer.duplicate?).to be true
        expect(answer.points_awarded).to eq(0)
      end
    end

    it "awards 1 point for unique answers" do
      ci = game.current_round_categories.first

      # Each player gives a unique answer
      described_class.submit_answers(game: game.reload, player: player1, answers_params: { ci.id.to_s => "Apple" })
      described_class.submit_answers(game: game.reload, player: player2, answers_params: { ci.id.to_s => "Banana" })
      described_class.submit_answers(game: game.reload, player: player3, answers_params: { ci.id.to_s => "Cherry" })

      # Submit remaining categories
      game.current_round_categories.where.not(id: ci.id).each do |other_ci|
        [ player1, player2, player3 ].each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { other_ci.id.to_s => "Unique #{player.id} #{other_ci.id}" }
          )
        end
      end

      described_class.finish_review(game: game.reload)

      ci.category_answers.reload.each do |answer|
        expect(answer.points_awarded).to eq(1)
      end
    end

    it "awards 0 points for blank answers" do
      ci = game.current_round_categories.first

      described_class.submit_answers(game: game.reload, player: player1, answers_params: { ci.id.to_s => "" })
      described_class.submit_answers(game: game.reload, player: player2, answers_params: { ci.id.to_s => "Banana" })
      described_class.submit_answers(game: game.reload, player: player3, answers_params: { ci.id.to_s => "Cherry" })

      # Submit remaining categories
      game.current_round_categories.where.not(id: ci.id).each do |other_ci|
        [ player1, player2, player3 ].each do |player|
          described_class.submit_answers(
            game: game.reload,
            player:,
            answers_params: { other_ci.id.to_s => "Unique #{player.id} #{other_ci.id}" }
          )
        end
      end

      described_class.finish_review(game: game.reload)

      blank_answer = ci.category_answers.find_by(player: player1)
      expect(blank_answer.points_awarded).to eq(0)
    end
  end
end
