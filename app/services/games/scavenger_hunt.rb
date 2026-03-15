module Games
  module ScavengerHunt
    DEFAULT_TIMER_DURATION_MINUTES = 30

    def self.requires_capacity_check? = false

    def self.game_started(room:, timer_enabled: true, timer_duration: DEFAULT_TIMER_DURATION_MINUTES, show_instructions: true, **_extra)
      return if room.current_game.present?

      pack = room.hunt_pack || HuntPack.default
      return unless pack
      return if pack.hunt_prompts.empty?

      # Form sends minutes, store as seconds
      duration_minutes = timer_duration.to_i
      duration_minutes = DEFAULT_TIMER_DURATION_MINUTES if duration_minutes <= 0
      duration_seconds = duration_minutes * 60

      game = ScavengerHuntGame.create!(
        timer_duration: duration_seconds,
        timer_enabled: true,
        hunt_pack: pack
      )

      # Create prompt instances from pack
      pack.hunt_prompts.ordered.each_with_index do |prompt, index|
        game.hunt_prompt_instances.create!(
          hunt_prompt: prompt,
          position: index
        )
      end

      room.update!(current_game: game)
      GameBroadcaster.broadcast_game_start(room:)

      if show_instructions
        broadcast_all(game)
      else
        start_from_instructions(game:)
      end
    end

    def self.start_from_instructions(game:)
      game.with_lock do
        return unless game.instructions?
        game.start_hunt!
      end

      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.handle_timeout(game:)
      game.with_lock do
        return unless game.hunting?
        game.end_hunting!
      end

      broadcast_all(game)
    end

    def self.submit_photo(game:, player:, prompt_instance:, media:)
      return unless game.accepts_submissions?

      submission = prompt_instance.hunt_submissions.find_or_initialize_by(player:)
      submission.late = game.times_up?
      submission.media.attach(media)
      submission.save!

      broadcast_all(game)
      submission
    rescue ActiveRecord::RecordNotUnique
      # Concurrent duplicate — reload and retry
      submission = prompt_instance.hunt_submissions.find_by!(player:)
      submission.media.attach(media)
      submission.save!
      broadcast_all(game)
      submission
    end

    def self.lock_submissions_manually(game:)
      game.with_lock do
        return unless game.hunting?
        game.end_hunting!
      end

      broadcast_all(game)
    end

    def self.start_reveal(game:)
      game.with_lock do
        return unless game.hunting? || game.times_up?
        game.start_reveal!
      end

      broadcast_all(game)
    end

    def self.show_submission_on_stage(game:, submission:)
      game.with_lock do
        return unless game.revealing?
        game.update!(currently_showing_submission_id: submission.id)
      end

      broadcast_all(game)
    end

    def self.start_awards(game:)
      game.with_lock do
        return unless game.revealing?
        game.start_awards!
      end

      broadcast_all(game)
    end

    def self.pick_winner(game:, prompt_instance:, submission:)
      game.with_lock do
        return unless game.awarding?
        prompt_instance.update!(winner_submission: submission)
      end

      broadcast_all(game)
    end

    def self.finish_game(game:)
      game.with_lock do
        return unless game.awarding?
        calculate_scores(game)
        game.finish_game!
      end

      game.room.finish!
      broadcast_all(game)
    end

    def self.mark_completed(game:, submission:, completed:)
      submission.update!(completed:)
      broadcast_curation(game)
    end

    def self.mark_favorite(game:, submission:, favorite:)
      submission.update!(favorite:)
      broadcast_curation(game)
    end

    def self.update_host_notes(game:, submission:, notes:)
      submission.update!(host_notes: notes)
      broadcast_curation(game)
    end

    # --- Private ---

    def self.start_timer_if_enabled(game)
      return unless game.timer_enabled?
      game.start_timer!(game.timer_duration)
    end

    def self.calculate_scores(game)
      game.hunt_prompt_instances.includes(:hunt_submissions, :winner_submission, :hunt_prompt).find_each do |instance|
        weight = instance.weight

        # Completion points for all submissions with media
        instance.hunt_submissions.joins(:media_attachment).each do |sub|
          sub.player.increment!(:score, weight)
        end

        # Winner bonus
        if instance.winner_submission
          instance.winner_submission.player.increment!(:score, weight)
        end
      end
    end

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:, game:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    def self.broadcast_curation(game)
      room = game.room
      GameBroadcaster.broadcast_host_controls(room:)
    end

    private_class_method :start_timer_if_enabled, :calculate_scores, :broadcast_all, :broadcast_curation

    # --- Playtest ---

    module Playtest
      def self.start(room:)
        Games::ScavengerHunt.game_started(room:, timer_enabled: false, show_instructions: true)
      end

      def self.advance(game:)
        case game.status
        when "instructions"
          Games::ScavengerHunt.start_from_instructions(game:)
        when "hunting"
          Games::ScavengerHunt.lock_submissions_manually(game:)
        when "times_up"
          Games::ScavengerHunt.start_reveal(game:)
        when "revealing"
          Games::ScavengerHunt.start_awards(game:)
        when "awarding"
          Games::ScavengerHunt.finish_game(game:)
        end
      end

      def self.bot_act(game:, exclude_player:)
        return unless game.hunting? || game.times_up?

        players = game.room.players.active_players.where.not(id: exclude_player&.id)
        fixture_path = Rails.root.join("spec/fixtures/files/test_photo.jpg")

        players.each do |player|
          game.hunt_prompt_instances.each do |instance|
            next if instance.hunt_submissions.exists?(player:)
            next if rand > 0.6

            submission = instance.hunt_submissions.find_or_initialize_by(player:)
            submission.late = game.times_up?
            submission.media.attach(
              io: File.open(fixture_path),
              filename: "bot_photo_#{player.id}_#{instance.id}.jpg",
              content_type: "image/jpeg"
            )
            submission.save!
          end
        end

        Games::ScavengerHunt.send(:broadcast_all, game)
      end

      def self.auto_play_step(game:)
        case game.status
        when "instructions"
          Games::ScavengerHunt.start_from_instructions(game:)
        when "hunting"
          bot_act(game:, exclude_player: nil)
          HuntSubmission.joins(:hunt_prompt_instance)
                        .where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id })
                        .update_all(completed: true)
          Games::ScavengerHunt.lock_submissions_manually(game:)
        when "times_up"
          Games::ScavengerHunt.start_reveal(game:)
        when "revealing"
          Games::ScavengerHunt.start_awards(game:)
        when "awarding"
          game.hunt_prompt_instances.each do |instance|
            winner = instance.hunt_submissions.joins(:media_attachment).first
            instance.update!(winner_submission: winner) if winner
          end
          Games::ScavengerHunt.finish_game(game:)
        end
      end

      def self.progress_label(game:)
        submitted = HuntSubmission.joins(:hunt_prompt_instance)
                                  .where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id })
                                  .count
        total = game.hunt_prompt_instances.count * game.room.players.active_players.count
        "#{submitted}/#{total} submissions"
      end

      def self.dashboard_actions(status)
        case status
        when "lobby"
          [ { label: "Start Game", action: :start, style: :primary } ]
        when "instructions"
          [ { label: "Skip Instructions", action: :advance, style: :primary } ]
        when "hunting"
          [
            { label: "Bots: Submit Photos", action: :bot_act, style: :bot },
            { label: "End Hunting", action: :advance, style: :primary }
          ]
        when "times_up"
          [ { label: "Start Presentation", action: :advance, style: :primary } ]
        when "revealing"
          [ { label: "Start Awards", action: :advance, style: :primary } ]
        when "awarding"
          [ { label: "Finish Game", action: :advance, style: :primary } ]
        else
          []
        end
      end
    end
  end
end
