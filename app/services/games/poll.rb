module Games
  module Poll
    DEFAULT_QUESTION_COUNT = 5
    DEFAULT_TIME_LIMIT = 20

    def self.requires_capacity_check? = false

    def self.game_started(room:, question_count: DEFAULT_QUESTION_COUNT, time_limit: DEFAULT_TIME_LIMIT,
                          scoring_mode: "majority", timer_enabled: false, timer_increment: nil,
                          show_instructions: true, **_extra)
      return if room.current_game.present?

      effective_time_limit = timer_increment.presence || time_limit
      pack = room.poll_pack || PollPack.default

      game = PollGame.create!(
        poll_pack: pack,
        scoring_mode:,
        question_count:,
        time_limit: effective_time_limit,
        timer_enabled:
      )
      room.update!(current_game: game)

      assign_questions(game:, question_count:)
      GameEvent.log(game, "game_created", game_type: room.game_type,
                    player_count: room.players.active_players.count,
                    scoring_mode:, timer_enabled:)

      game.start_game! unless show_instructions

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
      question = game.current_question
      return if question.nil?

      existing = PollAnswer.find_by(player:, poll_question: question, poll_game: game)
      return existing if existing.present?

      answer = PollAnswer.new(
        player:,
        poll_game: game,
        poll_question: question,
        selected_option:,
        submitted_at: Time.current
      )

      begin
        answer.save!
      rescue ActiveRecord::RecordNotUnique
        return PollAnswer.find_by!(player:, poll_question: question, poll_game: game)
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

        unless game.host_choose?
          score_current_round(game)
          game.calculate_scores!
        end
      end
      GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
      broadcast_all(game)
    end

    def self.set_host_answer(game:, answer:)
      game.with_lock do
        return unless game.reviewing?
        return unless game.host_choose?

        game.update!(host_chosen_answer: answer)
        score_current_round(game)
        game.calculate_scores!
      end
      broadcast_all(game)
    end

    def self.next_question(game:)
      finished = false
      game.with_lock do
        if game.questions_remaining?
          game.next_question!
        else
          game.previous_top_player_ids = game.room.players.active_players
            .order(score: :desc).limit(4).pluck(:id)
          game.calculate_scores!
          game.finish_game!
          GameEvent.log(game, "game_finished",
                        duration_seconds: (Time.current - game.created_at).to_i,
                        player_count: game.room.players.active_players.count)
          game.room.finish!
          finished = true
        end
      end

      if finished
        broadcast_all(game)
      else
        start_question(game:)
      end
    end

    def self.handle_timeout(game:)
      return unless game.answering?

      close_round(game:)
    end

    def self.assign_questions(game:, question_count:)
      pack = game.poll_pack || PollPack.default
      questions = pack.poll_questions.order(:position).limit(question_count).to_a

      raise "Not enough poll questions to start game." if questions.size < question_count

      questions.each_with_index do |question, index|
        question.update!(position: index) if question.position != index
      end
    end

    def self.score_current_round(game)
      question = game.current_question
      return unless question

      answers = game.poll_answers.where(poll_question: question)
      winner = determine_winner(game, question)

      answers.find_each do |answer|
        won = if winner.nil?
          false
        elsif game.host_choose?
          answer.selected_option == winner
        elsif game.majority?
          answer.selected_option == winner
        else # minority
          answer.selected_option != winner
        end

        points = if won
          answer.calculate_points(
            round_started_at: game.round_started_at,
            round_closed_at: game.round_closed_at
          )
        else
          0
        end

        answer.update!(points_awarded: points)
      end
    end

    def self.determine_winner(game, question)
      if game.host_choose?
        game.host_chosen_answer
      else
        game.majority_option(question)
      end
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

    private_class_method :assign_questions, :score_current_round, :determine_winner,
                         :start_timer_if_enabled, :broadcast_all

    module Playtest
      def self.start(room:)
        Games::Poll.game_started(room:, show_instructions: true, timer_enabled: false)
      end

      def self.advance(game:)
        case game.status
        when "instructions" then Games::Poll.start_from_instructions(game:)
        when "waiting"      then Games::Poll.start_question(game:)
        when "answering"    then Games::Poll.close_round(game:)
        when "reviewing"
          if game.host_choose? && game.host_chosen_answer.blank?
            question = game.current_question
            Games::Poll.set_host_answer(game:, answer: question&.options&.first)
          else
            Games::Poll.next_question(game:)
          end
        end
      end

      def self.bot_act(game:, exclude_player:)
        return unless game.answering?

        question = game.current_question
        return unless question

        bots = game.room.players
        bots = bots.where.not(id: exclude_player.id) if exclude_player

        bots.each do |bot|
          next if PollAnswer.exists?(player: bot, poll_question: question, poll_game: game)

          option = question.options.sample
          Games::Poll.submit_answer(game:, player: bot, selected_option: option)
        end
      end

      def self.auto_play_step(game:)
        case game.status
        when "instructions" then Games::Poll.start_from_instructions(game:)
        when "waiting"      then Games::Poll.start_question(game:)
        when "answering"
          bot_act(game:, exclude_player: nil)
          game.reload
          Games::Poll.close_round(game:) if game.answering?
        when "reviewing"
          advance(game:)
        end
      end

      def self.progress_label(game:)
        total = game.poll_pack&.poll_questions&.count || 0
        "Question #{game.current_question_index + 1} of #{total}"
      end

      def self.dashboard_actions(status)
        case status
        when "lobby"        then [ { label: "Start Game", action: :start, style: :primary } ]
        when "instructions" then [ { label: "Skip Instructions", action: :advance, style: :primary } ]
        when "waiting"      then [ { label: "Start Question", action: :advance, style: :primary } ]
        when "answering"
          [
            { label: "Bots: Answer", action: :bot_act, style: :bot },
            { label: "Close Voting", action: :advance, style: :primary }
          ]
        when "reviewing"    then [ { label: "Next Question", action: :advance, style: :primary } ]
        when "finished"     then []
        else                     []
        end
      end
    end
  end
end
