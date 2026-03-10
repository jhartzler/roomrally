require "rails_helper"

RSpec.describe Games::ScavengerHunt do
  let!(:hunt_pack) { create(:hunt_pack, :default) }
  let!(:prompts) do
    3.times.map { |i| create(:hunt_prompt, hunt_pack:, body: "Prompt #{i + 1}", position: i) }
  end
  let!(:room) { create(:room, game_type: "Scavenger Hunt") }
  let!(:host) { create(:player, room:, name: "Host", team_name: "Team Alpha") }
  let!(:player2) { create(:player, room:, name: "Alice", team_name: "Team Beta") }

  describe ".game_started" do
    it "creates a game with prompt instances" do
      described_class.game_started(room:, timer_enabled: true, timer_duration: 30, show_instructions: true)
      game = room.reload.current_game

      expect(game).to be_a(ScavengerHuntGame)
      expect(game).to be_instructions
      expect(game.hunt_prompt_instances.count).to eq(3)
      expect(game.timer_duration).to eq(1800) # 30 minutes * 60 seconds
    end
  end

  describe ".start_from_instructions" do
    let!(:game) { start_game }

    it "transitions to hunting" do
      described_class.start_from_instructions(game:)
      expect(game.reload).to be_hunting
    end
  end

  describe ".submit_photo" do
    let!(:game) { start_and_begin_hunt }

    it "creates a submission for a prompt" do
      instance = game.hunt_prompt_instances.first
      media = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      submission = described_class.submit_photo(game:, player: host, prompt_instance: instance, media:)

      expect(submission).to be_persisted
      expect(submission.media).to be_attached
      expect(submission.late).to be false
    end

    it "flags late submissions when times_up" do
      described_class.lock_submissions_manually(game:)
      instance = game.hunt_prompt_instances.first
      media = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      submission = described_class.submit_photo(game:, player: host, prompt_instance: instance, media:)

      expect(submission.late).to be true
    end

    it "replaces existing submission for same prompt and player" do
      instance = game.hunt_prompt_instances.first
      media1 = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")
      media2 = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      described_class.submit_photo(game:, player: host, prompt_instance: instance, media: media1)
      described_class.submit_photo(game:, player: host, prompt_instance: instance, media: media2)

      expect(instance.hunt_submissions.where(player: host).count).to eq(1)
    end
  end

  describe ".handle_timeout" do
    it "transitions to times_up when timer expires" do
      game = start_and_begin_hunt
      described_class.handle_timeout(game:)
      expect(game.reload).to be_times_up
    end
  end

  describe ".finish_game" do
    it "calculates scores based on completions and winners" do
      game = start_and_begin_hunt
      instance = game.hunt_prompt_instances.first

      sub_host = create(:hunt_submission, hunt_prompt_instance: instance, player: host, completed: true)
      create(:hunt_submission, hunt_prompt_instance: instance, player: player2, completed: true)

      instance.update!(winner_submission: sub_host)

      described_class.start_reveal(game:)
      described_class.start_awards(game:)
      described_class.finish_game(game:)

      # Host: 5 (completion) + 5 (winner) = 10
      expect(host.reload.score).to eq(10)
      # Player2: 5 (completion)
      expect(player2.reload.score).to eq(5)
    end
  end

  # Helper methods
  def start_game
    described_class.game_started(room:, timer_enabled: false, timer_duration: 30, show_instructions: true)
    room.reload.current_game
  end

  def start_and_begin_hunt
    game = start_game
    described_class.start_from_instructions(game:)
    game.reload
  end
end
