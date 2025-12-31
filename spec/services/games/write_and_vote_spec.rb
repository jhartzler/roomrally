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

    it 'creates the correct number of prompt instances' do
      expect { described_class.game_started(room:) }.to change(PromptInstance, :count).by(3)
    end

    it 'creates the correct number of responses' do
      expect { described_class.game_started(room:) }.to change(Response, :count).by(6)
    end

    it 'assigns two prompts to player one' do
      described_class.game_started(room:)
      expect(first_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player two' do
      described_class.game_started(room:)
      expect(second_player.responses.count).to eq(2)
    end

    it 'assigns two prompts to player three' do
      described_class.game_started(room:)
      expect(third_player.responses.count).to eq(2)
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

      it 'raises an error' do
        expect { described_class.game_started(room:) }.to raise_error("Not enough master prompts to start round 1.")
      end
    end

    it 'starts the round timer', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      # Spy on the game creation to intercept the instance
      game_spy = nil
      allow(WriteAndVoteGame).to receive(:create!).and_wrap_original do |original_method, *args|
        game_spy = original_method.call(*args)
        allow(game_spy).to receive(:start_timer!) # Spy on this method
        game_spy
      end

      described_class.game_started(room:, timer_enabled: true)

      # Default timer is 60 (from migration/model default), so start_timer! is called with 60
      expect(game_spy).to have_received(:start_timer!).with(60, step_number: nil)
    end

    describe "configuration parameters" do
      it "creates game with custom timer settings" do
        described_class.game_started(room:, timer_enabled: true, timer_increment: 90)
        game = room.current_game
        expect(game.timer_enabled).to be true
        expect(game.timer_increment).to eq(90)
      end

      it "uses custom timer increment when starting timer" do
        game_spy = nil
        allow(WriteAndVoteGame).to receive(:create!).and_wrap_original { |m, *args| m.call(*args).tap { |g| game_spy = g; allow(g).to receive(:start_timer!) } }

        described_class.game_started(room:, timer_enabled: true, timer_increment: 45)
        expect(game_spy).to have_received(:start_timer!).with(45, step_number: nil)
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
      described_class.assign_prompts_for_round(game:, round_number: 1)
      round_1_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 1).pluck(:prompt_id)

      # Round 2
      described_class.assign_prompts_for_round(game:, round_number: 2)
      round_2_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: 2).pluck(:prompt_id)

      # Intersection should be empty
      expect(round_1_prompt_ids & round_2_prompt_ids).to be_empty
    end

    it 'does not use DB-level RANDOM() sorting for scalability' do
      # Expecting order("RANDOM()") NOT to be called ensures we moved to app-level sampling
      expect_any_instance_of(ActiveRecord::Relation).not_to receive(:order).with("RANDOM()") # rubocop:disable RSpec/AnyInstance

      described_class.assign_prompts_for_round(game:, round_number: 1)
    end
  end

  describe '.check_all_responses_submitted' do
    let(:game) { create(:write_and_vote_game, status: "writing") }
    let(:room) { create(:room, current_game: game) }

    before do
      create(:prompt_instance, write_and_vote_game: game, round: 1)
      allow(room).to receive(:broadcast_replace_to).and_return(true)
    end

    it "transitions to voting when all responses are submitted" do
      # Setup responses as submitted
      game.prompt_instances.each do |pi|
        # Assume 2 players for simplicity
        create(:response, prompt_instance: pi, status: :submitted)
        create(:response, prompt_instance: pi, status: :submitted)
      end
      
      # Mock the check to return true (since we manually created them)
      allow(game).to receive(:all_responses_submitted?).and_return(true)
      allow(game).to receive(:start_timer!)

      described_class.check_all_responses_submitted(game:)

      expect(game.reload.status).to eq("voting")
    end

    it "does not transition if responses are missing" do
      allow(game).to receive(:all_responses_submitted?).and_return(false)
      
      described_class.check_all_responses_submitted(game:)
      
      expect(game.reload.status).to eq("writing")
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
