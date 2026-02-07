module DevPlaytest
  module SpeedTrivia
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

    # -- Bot behaviors (private) --

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
