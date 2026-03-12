module Games
  module SpeedTrivia
    DEFAULT_QUESTION_COUNT = 5
    DEFAULT_TIME_LIMIT = 20

    def self.requires_capacity_check? = false

    def self.game_started(room:, question_count: DEFAULT_QUESTION_COUNT, time_limit: DEFAULT_TIME_LIMIT, timer_enabled: false, timer_increment: nil, show_instructions: true, **_extra)
      # Use timer_increment if provided (from UI), otherwise fall back to time_limit
      effective_time_limit = timer_increment.presence || time_limit

      Rails.logger.info({
        event: "speed_trivia_game_started",
        room_code: room.code,
        player_count: room.players.active_players.count,
        question_count:,
        timer_enabled:,
        time_limit: effective_time_limit,
        show_instructions:
      })

      Analytics.track(
        distinct_id: room.user_id ? "user_#{room.user_id}" : "room_#{room.code}",
        event: "game_started",
        properties: { game_type: room.game_type, room_code: room.code, player_count: room.players.active_players.count, timer_enabled:, show_instructions: }
      )

      return if room.current_game.present?

      pack = room.trivia_pack || TriviaPack.default
      game = SpeedTriviaGame.create!(trivia_pack: pack, time_limit: effective_time_limit, timer_enabled:, show_instructions:)
      room.update!(current_game: game)

      assign_questions(game:, question_count:)

      GameEvent.log(game, "game_created", game_type: room.game_type, player_count: room.players.active_players.count, timer_enabled:)

      # Skip instructions if disabled
      unless show_instructions
        game.start_game!
        Analytics.track(
          distinct_id: room.user_id ? "user_#{room.user_id}" : "room_#{room.code}",
          event: "instructions_skipped",
          properties: { game_type: room.game_type, room_code: room.code }
        )
      end

      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
    end

    def self.start_from_instructions(game:)
      previous_status = game.status
      game.start_game!
      GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
      broadcast_all(game)
    end

    def self.start_question(game:)
      previous_status = game.status
      game.start_question!
      GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.submit_answer(game:, player:, selected_option:)
      current_question = game.current_question
      return if current_question.nil?

      # Fast path: bail early if already answered.
      existing = TriviaAnswer.find_by(player:, trivia_question_instance: current_question)
      return existing if existing.present?

      answer = TriviaAnswer.new(
        player:,
        trivia_question_instance: current_question,
        selected_option:,
        submitted_at: Time.current
      )
      answer.determine_correctness

      begin
        answer.save!
      rescue ActiveRecord::RecordNotUnique
        return TriviaAnswer.find_by!(player:, trivia_question_instance: current_question)
      end

      broadcast_all(game)

      answer
    end

    def self.close_round(game:)
      previous_status = game.status
      game.with_lock do
        return unless game.answering?

        game.previous_top_player_ids = game.room.players.active_players
          .order(score: :desc).limit(4).pluck(:id)
        game.close_round!
        score_current_round(game)
        game.calculate_scores!
      end
      GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
      broadcast_all(game)
    end

    def self.next_question(game:)
      game.with_lock do
        if game.questions_remaining?
          game.next_question!
          start_question(game:)
        else
          game.previous_top_player_ids = game.room.players.active_players
            .order(score: :desc).limit(4).pluck(:id)
          game.calculate_scores!
          game.finish_game!
          GameEvent.log(game, "game_finished", duration_seconds: (Time.current - game.created_at).to_i, player_count: game.room.players.active_players.count)
          Analytics.track(
            distinct_id: game.room.user_id ? "user_#{game.room.user_id}" : "room_#{game.room.code}",
            event: "game_completed",
            properties: { game_type: game.room.game_type, room_code: game.room.code, player_count: game.room.players.active_players.count, duration_seconds: (Time.current - game.created_at).to_i }
          )
          game.room.finish!
          broadcast_all(game)
        end
      end
    end

    def self.handle_timeout(game:)
      return unless game.answering?

      # Auto-close the round when timer expires
      close_round(game:)
    end

    def self.start_timer_if_enabled(game)
      return unless game.timer_enabled?

      game.start_timer!(game.time_limit)
    end

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:, game:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    def self.assign_questions(game:, question_count:)
      pack = game.trivia_pack || TriviaPack.default
      available_questions = pack.trivia_questions.to_a

      if available_questions.size < question_count
        raise "Not enough trivia questions to start game."
      end

      selected_questions = available_questions.sort_by { |q| [ q.position || Float::INFINITY, q.id ] }.first(question_count)

      selected_questions.each_with_index do |question, index|
        instance = TriviaQuestionInstance.create!(
          speed_trivia_game: game,
          trivia_question: question,
          body: question.body,
          correct_answers: question.correct_answers,
          options: question.options,
          position: index
        )
        instance.image.attach(question.image.blob) if question.image.attached?
      end
    end

    def self.score_current_round(game)
      return unless game.current_question

      game.current_question.trivia_answers.find_each do |answer|
        answer.update!(points_awarded: answer.calculate_points(
          round_started_at: game.round_started_at,
          round_closed_at: game.round_closed_at
        ))
      end
    end

    private_class_method :assign_questions, :start_timer_if_enabled, :broadcast_all, :score_current_round

    module Playtest
      def self.start(room:)
        Games::SpeedTrivia.game_started(room:, show_instructions: true, timer_enabled: false)
      end

      def self.advance(game:)
        case game.status
        when "instructions"
          Games::SpeedTrivia.start_from_instructions(game:)
        when "waiting"
          Games::SpeedTrivia.start_question(game:)
        when "answering"
          Games::SpeedTrivia.close_round(game:)
        when "reviewing"
          Games::SpeedTrivia.next_question(game:)
        end
      end

      def self.bot_act(game:, exclude_player:)
        case game.status
        when "answering"
          submit_answers(game:, exclude_player:)
        end
      end

      def self.auto_play_step(game:)
        case game.status
        when "instructions"
          Games::SpeedTrivia.start_from_instructions(game:)
        when "waiting"
          Games::SpeedTrivia.start_question(game:)
        when "answering"
          bot_act(game:, exclude_player: nil)
          game.reload
          Games::SpeedTrivia.close_round(game:) if game.answering?
        when "reviewing"
          Games::SpeedTrivia.next_question(game:)
        end
      end

      def self.progress_label(game:)
        "Question #{game.current_question_index + 1} of #{game.trivia_question_instances.count}"
      end

      def self.dashboard_actions(status)
        case status
        when "lobby"
          [ { label: "Start Game", action: :start, style: :primary } ]
        when "instructions"
          [ { label: "Skip Instructions", action: :advance, style: :primary } ]
        when "waiting"
          [ { label: "Start Question", action: :advance, style: :primary } ]
        when "answering"
          [
            { label: "Bots: Answer", action: :bot_act, style: :bot },
            { label: "Close Round", action: :advance, style: :primary }
          ]
        when "reviewing"
          [ { label: "Next Question", action: :advance, style: :primary } ]
        when "finished"
          []
        else
          []
        end
      end

      def self.submit_answers(game:, exclude_player:)
        current_question = game.current_question
        return unless current_question

        bot_players = game.room.players
        bot_players = bot_players.where.not(id: exclude_player.id) if exclude_player

        bot_players.each do |bot_player|
          next if TriviaAnswer.find_by(player: bot_player, trivia_question_instance: current_question)

          random_option = current_question.options.sample
          Games::SpeedTrivia.submit_answer(game:, player: bot_player, selected_option: random_option)
        end
      end

      private_class_method :submit_answers
    end
  end
end
