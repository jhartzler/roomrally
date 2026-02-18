module Games
  module SpeedTrivia
    DEFAULT_QUESTION_COUNT = 5
    DEFAULT_TIME_LIMIT = 20

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
        distinct_id: "room_#{room.code}",
        event: "game_started",
        properties: { game_type: "Speed Trivia", room_code: room.code, player_count: room.players.active_players.count, timer_enabled:, show_instructions: }
      )

      return if room.current_game.present?

      pack = room.trivia_pack || TriviaPack.default
      game = SpeedTriviaGame.create!(trivia_pack: pack, time_limit: effective_time_limit, timer_enabled:, show_instructions:)
      room.update!(current_game: game)

      assign_questions(game:, question_count:)

      # Skip instructions if disabled
      game.start_game! unless show_instructions

      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
    end

    def self.start_from_instructions(game:)
      game.start_game!
      broadcast_all(game)
    end

    def self.start_question(game:)
      game.start_question!
      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.submit_answer(game:, player:, selected_option:)
      current_question = game.current_question
      return if current_question.nil?

      # Prevent duplicate submissions
      existing = TriviaAnswer.find_by(player:, trivia_question_instance: current_question)
      return existing if existing.present?

      answer = TriviaAnswer.new(
        player:,
        trivia_question_instance: current_question,
        selected_option:,
        submitted_at: Time.current
      )
      answer.determine_correctness
      answer.points_awarded = answer.calculate_points(
        time_limit: game.time_limit,
        round_started_at: game.round_started_at,
        round_closed_at: game.round_closed_at || (game.round_started_at + game.time_limit.seconds)
      )
      answer.save!

      GameBroadcaster.broadcast_hand(room: game.room)
      GameBroadcaster.broadcast_stage(room: game.room)
      GameBroadcaster.broadcast_host_controls(room: game.room)

      answer
    end

    def self.close_round(game:)
      game.close_round!
      broadcast_all(game)
      schedule_score_reveal(game)
    end

    def self.show_scores(game:)
      return unless game.reviewing?

      # Capture current top-4 before recalculating
      game.previous_top_player_ids = game.room.players.active_players
        .order(score: :desc).limit(4).pluck(:id)

      game.calculate_scores!
      game.update!(reviewing_step: 2)

      broadcast_all(game)
    end

    def self.next_question(game:)
      if game.questions_remaining?
        game.next_question!
        start_question(game:)
      else
        game.previous_top_player_ids = game.room.players.active_players
          .order(score: :desc).limit(4).pluck(:id)
        game.calculate_scores!
        game.finish_game!
        Analytics.track(
          distinct_id: "room_#{game.room.code}",
          event: "game_completed",
          properties: { game_type: "Speed Trivia", room_code: game.room.code, player_count: game.room.players.active_players.count, duration_seconds: (Time.current - game.created_at).to_i }
        )
        game.room.finish!
        broadcast_all(game)
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

      selected_questions = available_questions.sample(question_count)

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

    def self.schedule_score_reveal(game)
      GameTimerJob.set(wait: SpeedTriviaGame::SCORE_REVEAL_DELAY.seconds)
        .perform_later(game, game.current_question_index, "score_reveal")
    end

    private_class_method :assign_questions, :start_timer_if_enabled, :broadcast_all, :schedule_score_reveal
  end
end
