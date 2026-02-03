require 'rails_helper'

RSpec.describe "Timer Bug Reproduction", type: :job do
  let(:prompt_pack) { FactoryBot.create(:prompt_pack) }
  let(:game) { WriteAndVoteGame.create!(prompt_pack:, timer_enabled: true, timer_increment: 30) }
  let(:room) { FactoryBot.create(:room, current_game: game, prompt_pack:) }

  before do
    # Create players for the room
    FactoryBot.create_list(:player, 3, room:)
    # Create prompt instances for the game
    FactoryBot.create_list(:prompt_instance, 3, write_and_vote_game: game, round: 1)
  end

  it "successfully runs the timer job for writing phase" do
    # Simulate start of game
    game.update!(status: 'writing', round: 1)

    # Enqueue job
    expect {
      GameTimerJob.perform_now(game, 1) # step_number nil
    }.not_to raise_error
  end

  it "successfully runs the timer job for voting phase" do
    # Simulate voting phase
    game.update!(status: 'voting', round: 1, current_prompt_index: 0)

    expect {
      GameTimerJob.perform_now(game, 1, 0)
    }.not_to raise_error
  end
end
