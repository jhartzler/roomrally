module Games
  module CategoryList
    DEFAULT_TOTAL_ROUNDS = 3
    DEFAULT_CATEGORIES_PER_ROUND = 6

    def self.game_started(room:, timer_enabled: false, timer_increment: 90, total_rounds: DEFAULT_TOTAL_ROUNDS, categories_per_round: DEFAULT_CATEGORIES_PER_ROUND, show_instructions: true, **_extra)
      total_rounds = DEFAULT_TOTAL_ROUNDS if total_rounds.to_i <= 0
      categories_per_round = DEFAULT_CATEGORIES_PER_ROUND if categories_per_round.to_i <= 0

      return if room.current_game.present?

      pack = room.category_pack || CategoryPack.default
      game = CategoryListGame.create!(
        category_pack: pack,
        timer_enabled:,
        timer_increment: timer_increment.to_i > 0 ? timer_increment.to_i : 90,
        total_rounds: total_rounds.to_i,
        categories_per_round: categories_per_round.to_i,
        show_instructions:
      )
      room.update!(current_game: game)

      setup_round(game:)

      game.start_game! unless show_instructions

      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
    end

    def self.start_from_instructions(game:)
      game.start_game!
      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.submit_answers(game:, player:, answers_params:)
      game.with_lock do
        answers_params.each do |category_instance_id, answer_text|
          ci = game.category_instances.find_by(id: category_instance_id)
          next unless ci

          CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
            answer.body = answer_text.to_s.strip
          end
        end

        if game.all_answers_submitted?
          game.begin_review!
          broadcast_all(game)
        else
          GameBroadcaster.broadcast_hand(room: game.room)
          GameBroadcaster.broadcast_stage(room: game.room)
          GameBroadcaster.broadcast_host_controls(room: game.room)
        end
      end
    end

    def self.finish_review(game:)
      game.update!(reviewing_category_position: 0)
      calculate_round_scores(game:)
      game.begin_scoring!
      broadcast_all(game)
    end

    def self.navigate_review(game:, direction:)
      max_position = game.current_round_categories.count - 1
      new_position = if direction == "next"
        [ game.reviewing_category_position + 1, max_position ].min
      else
        [ game.reviewing_category_position - 1, 0 ].max
      end
      game.update!(reviewing_category_position: new_position)
      broadcast_all(game)
    end

    def self.hide_answer(answer:)
      answer.update!(status: :hidden, points_awarded: 0)
    end

    def self.mark_duplicate(answer:)
      answer.update!(duplicate: true, points_awarded: 0)
    end

    def self.next_round(game:)
      if game.last_round?
        calculate_total_scores(game:)
        game.finish_game!
        game.room.finish!
        broadcast_all(game)
      else
        game.update!(current_round: game.current_round + 1)
        setup_round(game:)
        game.begin_next_round!
        start_timer_if_enabled(game)
        broadcast_all(game)
      end
    end

    def self.handle_timeout(game:)
      return unless game.filling?

      # Fill empty answers for players who haven't submitted
      fill_missing_answers(game:)

      if game.room.stage_only?
        # Stage-only: skip reviewing, go straight to scoring
        game.begin_review!
        game.begin_scoring!
      else
        game.begin_review!
      end
      broadcast_all(game)
    end

    def self.show_scores(game:)
      # Stage-only mode: skip reviewing, go straight to scoring
      if game.filling?
        game.begin_review!
        game.begin_scoring!
      elsif game.reviewing?
        calculate_round_scores(game:)
        game.begin_scoring!
      end
      broadcast_all(game)
    end

    def self.toggle_stage_scores(game:)
      return unless game.scoring?

      # Toggle: 0 = categories only, 1 = show scores on stage
      new_value = game.reviewing_category_position == 0 ? 1 : 0
      game.update!(reviewing_category_position: new_value)
      broadcast_all(game)
    end

    def self.reject_answer(answer:)
      answer.update!(status: :rejected, points_awarded: 0)
    end

    def self.approve_answer(answer:)
      answer.update!(status: :approved)
    end

    # Private methods

    def self.setup_round(game:)
      available_letters = CategoryListGame::ELIGIBLE_LETTERS - (game.used_letters || [])
      available_letters = CategoryListGame::ELIGIBLE_LETTERS if available_letters.empty?

      letter = available_letters.sample
      game.update!(
        current_letter: letter,
        used_letters: (game.used_letters || []) + [ letter ]
      )

      pack = game.category_pack || CategoryPack.default
      available_categories = pack.categories.to_a
      selected = available_categories.sample(game.categories_per_round)

      selected.each_with_index do |category, index|
        CategoryInstance.create!(
          category_list_game: game,
          category:,
          name: category.name,
          position: index,
          round: game.current_round
        )
      end
    end

    def self.fill_missing_answers(game:)
      players = game.room.players.active_players
      game.current_round_categories.each do |ci|
        players.each do |player|
          CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
            answer.body = ""
          end
        end
      end
    end

    def self.calculate_round_scores(game:)
      game.current_round_categories.each do |ci|
        answers = ci.category_answers.includes(:player).to_a

        # Normalize answers for comparison
        normalized = answers.map { |a| [ a, normalize_answer(a.body) ] }

        # Group by normalized answer to find duplicates
        groups = normalized.group_by { |_, norm| norm }

        normalized.each do |answer, norm|
          next if answer.rejected? || answer.hidden? || answer.duplicate?

          if norm.blank?
            answer.update!(points_awarded: 0)
          elsif groups[norm].size > 1
            answer.update!(duplicate: true, points_awarded: 0)
          elsif alliterative?(answer.body, game.current_letter)
            answer.update!(alliterative: true, points_awarded: CategoryListGame::POINTS_ALLITERATIVE)
          else
            answer.update!(points_awarded: CategoryListGame::POINTS_NORMAL)
          end
        end
      end
    end

    def self.calculate_total_scores(game:)
      game.room.players.active_players.each do |player|
        score = game.category_answers.where(player:).sum(:points_awarded)
        player.update!(score:)
      end
    end

    def self.normalize_answer(text)
      return "" if text.blank?

      text.strip.downcase
          .gsub(/\A(the|a|an)\s+/i, "")
          .gsub(/[^a-z0-9\s]/, "")
          .squish
    end

    def self.alliterative?(text, letter)
      return false if text.blank? || letter.blank?

      cleaned = text.strip.gsub(/\A(the|a|an)\s+/i, "")
      words = cleaned.split(/\s+/)
      return false if words.size < 2

      words.all? { |w| w[0]&.downcase == letter.downcase }
    end

    def self.start_timer_if_enabled(game)
      return unless game.timer_enabled?

      game.start_timer!(game.timer_increment)
    end

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    private_class_method :setup_round, :fill_missing_answers, :calculate_round_scores,
                         :calculate_total_scores, :normalize_answer, :alliterative?,
                         :start_timer_if_enabled, :broadcast_all
  end
end
