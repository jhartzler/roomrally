# spec/services/games/write_and_vote_spec.rb
require 'rails_helper'

RSpec.describe Games::WriteAndVote do
  describe '.game_started' do
    let(:room) { create(:room) }
    let!(:first_player) { create(:player, room:) }
    let!(:second_player) { create(:player, room:) }
    let!(:third_player) { create(:player, room:) }

    let!(:default_pack) { create(:prompt_pack, :default) }

    before do
      # Create some master prompts in the default pack so they can be found
      3.times { |i| create(:prompt, body: "Master Prompt #{i + 1}", prompt_pack: default_pack) }
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    it 'is idempotent (does not create duplicates if called twice)' do
      described_class.game_started(room:)
      expect { described_class.game_started(room:) }.not_to change(WriteAndVoteGame, :count)
    end

    it 'creates a WriteAndVoteGame and associates it with the room' do
      expect { described_class.game_started(room:) }.to change(WriteAndVoteGame, :count).by(1)
      expect(room.reload.current_game).to be_a(WriteAndVoteGame)
    end

    context 'with show_instructions: false (skips instructions)' do
      it 'creates the correct number of prompt instances' do
        expect { described_class.game_started(room:, show_instructions: false) }.to change(PromptInstance, :count).by(3)
      end

      it 'creates the correct number of responses' do
        expect { described_class.game_started(room:, show_instructions: false) }.to change(Response, :count).by(6)
      end

      it 'assigns two prompts to player one' do
        described_class.game_started(room:, show_instructions: false)
        expect(first_player.responses.count).to eq(2)
      end

      it 'assigns two prompts to player two' do
        described_class.game_started(room:, show_instructions: false)
        expect(second_player.responses.count).to eq(2)
      end

      it 'assigns two prompts to player three' do
        described_class.game_started(room:, show_instructions: false)
        expect(third_player.responses.count).to eq(2)
      end
    end

    context 'with show_instructions: true (default)' do
      it 'starts in instructions state without assigning prompts' do
        expect { described_class.game_started(room:) }.not_to change(PromptInstance, :count)
        expect(room.current_game.status).to eq("instructions")
      end
    end

    it 'assigns each prompt instance to two players' do
      described_class.game_started(room:)
      prompt_instance_assignments = Response.group(:prompt_instance_id).count
      prompt_instance_assignments.each_value do |count|
        expect(count).to eq(2)
      end
    end

    context 'when there are not enough master prompts' do
      before do
        Prompt.destroy_all
      end

      it 'raises an error when show_instructions is false' do
        expect { described_class.game_started(room:, show_instructions: false) }.to raise_error("Not enough master prompts to start round 1.")
      end
    end

    it 'starts the round timer when show_instructions is false', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      # Spy on the game creation to intercept the instance
      game_spy = nil
      allow(WriteAndVoteGame).to receive(:create!).and_wrap_original do |original_method, *args|
        game_spy = original_method.call(*args)
        allow(game_spy).to receive(:start_timer!) # Spy on this method
        game_spy
      end

      described_class.game_started(room:, timer_enabled: true, show_instructions: false)

      expect(game_spy).to have_received(:start_timer!).with(90, step_number: nil)
    end

    describe "configuration parameters" do
      it "creates game with custom timer settings" do
        described_class.game_started(room:, timer_enabled: true, timer_increment: 90, show_instructions: false)
        game = room.current_game
        expect(game.timer_enabled).to be true
        expect(game.timer_increment).to eq(90)
      end

      it "uses custom timer increment when starting timer" do
        game_spy = nil
        allow(WriteAndVoteGame).to receive(:create!).and_wrap_original { |m, *args| m.call(*args).tap { |g| game_spy = g; allow(g).to receive(:start_timer!) } }

        described_class.game_started(room:, timer_enabled: true, timer_increment: 45, show_instructions: false)
        expect(game_spy).to have_received(:start_timer!).with(45, step_number: nil)
      end
    end
  end

  describe '.finish_game!' do
    let!(:default_pack) { create(:prompt_pack, :default) }
    let(:game) { create(:write_and_vote_game, status: "voting", prompt_pack: default_pack) }
    let(:room) { create(:room, current_game: game, game_type: "Write And Vote", status: "playing") }

    before do
      create(:player, room:).tap { |p| room.update!(host: p) }
      allow(GameBroadcaster).to receive(:broadcast_stage)
      allow(GameBroadcaster).to receive(:broadcast_hand)
      allow(GameBroadcaster).to receive(:broadcast_host_controls)
      allow(GameBroadcaster).to receive(:broadcast_stage_lobby)
      allow(GameBroadcaster).to receive(:broadcast_lobby)
    end

    context 'with scoreable data' do
      let!(:player) { create(:player, room:, score: 0) }
      let!(:voter) { create(:player, room:) }

      before do
        prompt = create(:prompt_instance, write_and_vote_game: game)
        response = create(:response, player:, prompt_instance: prompt, body: "Funny answer")
        create(:vote, response:, player: voter)
      end

      it 'finishes the game' do
        described_class.finish_game!(game:)
        expect(game.reload.status).to eq("finished")
      end

      it 'finishes the room' do
        described_class.finish_game!(game:)
        expect(room.reload.status).to eq("finished")
      end

      it 'calculates scores' do
        described_class.finish_game!(game:)
        expect(player.reload.score).to eq(500)
      end

      it 'logs a game_finished event' do
        described_class.finish_game!(game:)
        event = GameEvent.find_by(eventable: game, event_name: "game_finished")
        expect(event).to be_present
        expect(event.metadata["details"]).to eq("ended by host")
      end

      it 'broadcasts game state' do
        described_class.finish_game!(game:)
        expect(GameBroadcaster).to have_received(:broadcast_stage)
      end
    end

    context 'without scoreable data' do
      it 'destroys the game' do
        # Ensure game and room are created
        room
        expect { described_class.finish_game!(game:) }.to change(WriteAndVoteGame, :count).by(-1)
      end

      it 'resets room to lobby' do
        room
        described_class.finish_game!(game:)
        expect(room.reload.status).to eq("lobby")
      end

      it 'nils out current_game' do
        room
        described_class.finish_game!(game:)
        expect(room.reload.current_game).to be_nil
      end

      it 'broadcasts lobby state' do
        room
        described_class.finish_game!(game:)
        expect(GameBroadcaster).to have_received(:broadcast_lobby).with(room:)
      end
    end
  end

  describe '.process_vote' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:default_pack) { create(:prompt_pack, :default) }
    let(:game) { create(:write_and_vote_game, status: 'voting', prompt_pack: default_pack, timer_enabled: true) }
    let(:room) { create(:room, current_game: game) }
    let(:players) { create_list(:player, 3, room:) }
    let!(:prompts) { create_list(:prompt_instance, 3, write_and_vote_game: game) }

    before do
      # Assign responses so that for each prompt, 2 players are authors and 1 is a voter.
      # Prompt 0: P0 & P1 are authors. P2 votes.
      # Prompt 1: P1 & P2 are authors. P0 votes.
      # Prompt 2: P2 & P0 are authors. P1 votes.
      prompts.each_with_index do |prompt, index|
        author1 = players[index]
        author2 = players[(index + 1) % 3]
        create(:response, prompt_instance: prompt, player: author1)
        create(:response, prompt_instance: prompt, player: author2)
      end
      # Allow calls to calculate_scores! on the game instance
      allow(game).to receive(:calculate_scores!)
      # Create extra prompts for Round 2 logic, associated with the game's pack
      create_list(:prompt, 3, prompt_pack: default_pack)
    end

    def cast_vote(player, prompt, response = nil)
      response ||= prompt.responses.where.not(player:).first
      create(:vote, player:, response:)
    end

    context 'when the non-author votes on the first prompt' do
      it 'advances to the next voting round' do
        voter = players[2] # P2 is the voter for Prompt 0
        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, prompts.first))
        }.to change(game, :current_prompt_index).by(1)
      end


      it 'starts the timer for the next prompt' do
        voter = players[2]
        allow(game).to receive(:start_timer!)
        described_class.process_vote(game:, vote: cast_vote(voter, prompts.first))
        expect(game).to have_received(:start_timer!).with(60, step_number: 1)
      end
    end

    context 'when the non-author votes on the last prompt of round 1' do
      before do
        game.update!(current_prompt_index: 2) # Last prompt (index 2 of 3)
      end

      it 'advances to the next game round (writing)' do
        voter = players[1] # P1 is the voter for Prompt 2

        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, prompts.last))
        }.to change(game, :round).by(1)
         .and change(game, :status).to("writing")
      end

      it 'calculates scores at the end of the round' do
        voter = players[1]
        described_class.process_vote(game:, vote: cast_vote(voter, prompts.last))
        expect(game).to have_received(:calculate_scores!)
      end
    end

    context 'when the non-author votes on the last prompt of round 2' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:round_2_prompts) { create_list(:prompt_instance, 3, write_and_vote_game: game, round: 2) }

      before do
        game.update!(round: 2, current_prompt_index: 2)
        round_2_prompts.each_with_index do |prompt, index|
          author1 = players[index]
          author2 = players[(index + 1) % 3]
          create(:response, prompt_instance: prompt, player: author1)
          create(:response, prompt_instance: prompt, player: author2)
        end
      end

      it 'finishes the game' do
        voter = players[1] # P1 is the voter for Prompt 2
        expect {
          described_class.process_vote(game:, vote: cast_vote(voter, round_2_prompts.last))
        }.to change(game, :status).to("finished")
      end

      it 'finishes the room' do
        room.update!(status: 'playing')
        voter = players[1] # P1 is the voter for Prompt 2
        described_class.process_vote(game:, vote: cast_vote(voter, round_2_prompts.last))
        expect(room.reload.status).to eq("finished")
      end

      it 'calculates scores at the end of the game' do
        voter = players[1]
        described_class.process_vote(game:, vote: cast_vote(voter, round_2_prompts.last))
        expect(game).to have_received(:calculate_scores!)
      end
    end
  end

  describe 'prompt reuse' do
    let(:room) { create(:room) }
    let(:game) { create(:write_and_vote_game, room:) }

    before do
      create_list(:player, 3, room:)
      Prompt.destroy_all
      default_pack = create(:prompt_pack, :default)
      # Create exactly 6 prompts for 3 players in the default pack
      # R1 takes 3. R2 takes 3. With fix, should succeed with 0 intersection.
      create_list(:prompt, 6, prompt_pack: default_pack)
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    it 'does not reuse prompts between rounds' do
      # Round 1
      described_class.send(:assign_prompts_for_round, game:, round_number: 1)
      round_1_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 1).pluck(:prompt_id)

      # Round 2
      described_class.send(:assign_prompts_for_round, game:, round_number: 2)
      round_2_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 2).pluck(:prompt_id)

      # Intersection should be empty
      expect(round_1_prompt_ids & round_2_prompt_ids).to be_empty
    end

    it 'does not use DB-level RANDOM() sorting for scalability' do
      # Expecting order("RANDOM()") NOT to be called ensures we moved to app-level sampling
      expect_any_instance_of(ActiveRecord::Relation).not_to receive(:order).with("RANDOM()") # rubocop:disable RSpec/AnyInstance

      described_class.send(:assign_prompts_for_round, game:, round_number: 1)
    end
  end


  describe '.handle_timeout' do
    let(:room) { create(:room) }
    let(:game) { create(:write_and_vote_game, room:, status: "writing", timer_enabled: true) }

    before do
      allow(game).to receive(:start_timer!)
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    context "when writing phase times out" do
      it "advances to voting and starts timer" do
        described_class.handle_timeout(game:)
        expect(game.reload.status).to eq("voting")
        expect(game).to have_received(:start_timer!).with(60, step_number: 0)
      end

      it "auto-fills missing responses" do
        prompt = create(:prompt_instance, write_and_vote_game: game, round: game.round)
        response = create(:response, prompt_instance: prompt, body: nil)

        described_class.handle_timeout(game:)
        expect(response.reload.body).to eq("Ran out of time!")
      end
    end

    context "when voting phase times out" do
      before do
        game.update!(status: "voting", current_prompt_index: 0)
        create_list(:prompt_instance, 2, write_and_vote_game: game, round: game.round) # 2 prompts
      end

      it "advances to next prompt and restarts timer" do
        described_class.handle_timeout(game:)

        expect(game.reload.current_prompt_index).to eq(1)
        expect(game).to have_received(:start_timer!).with(60, step_number: 1)
      end
    end
  end
end
