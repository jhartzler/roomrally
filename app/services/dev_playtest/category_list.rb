module DevPlaytest
  module CategoryList
    def self.start(room:)
      Games::CategoryList.game_started(room:, show_instructions: true, timer_enabled: false)
    end

    def self.advance(game:)
      case game.status
      when "instructions"
        Games::CategoryList.start_from_instructions(game:)
      when "filling"
        Games::CategoryList.handle_timeout(game:)
      when "reviewing"
        Games::CategoryList.finish_review(game:)
      when "scoring"
        Games::CategoryList.next_round(game:)
      end
    end

    def self.bot_act(game:, exclude_player:)
      case game.status
      when "filling"
        submit_answers(game:, exclude_player:)
      end
    end

    def self.auto_play_step(game:)
      case game.status
      when "instructions"
        Games::CategoryList.start_from_instructions(game:)
      when "filling"
        bot_act(game:, exclude_player: nil)
        game.reload
        Games::CategoryList.handle_timeout(game:) if game.filling?
      when "reviewing"
        Games::CategoryList.finish_review(game:)
      when "scoring"
        Games::CategoryList.next_round(game:)
      end
    end

    def self.progress_label(game:)
      "Round #{game.current_round} of #{game.total_rounds} — Letter: #{game.current_letter}"
    end

    def self.dashboard_actions(status)
      case status
      when "lobby"
        [ { label: "Start Game", action: :start, style: :primary } ]
      when "instructions"
        [ { label: "Skip Instructions", action: :advance, style: :primary } ]
      when "filling"
        [
          { label: "Bots: Submit Answers", action: :bot_act, style: :bot },
          { label: "End Round (Timeout)", action: :advance, style: :primary }
        ]
      when "reviewing"
        [ { label: "Finish Review", action: :advance, style: :primary } ]
      when "scoring"
        [ { label: "Next Round", action: :advance, style: :primary } ]
      when "finished"
        []
      else
        []
      end
    end

    # -- Bot behaviors (private) --

    def self.submit_answers(game:, exclude_player:)
      letter = game.current_letter
      categories = game.current_round_categories

      bot_players = game.room.players.active_players
      bot_players = bot_players.where.not(id: exclude_player.id) if exclude_player

      bot_players.each do |bot_player|
        answers_params = {}
        categories.each do |ci|
          next if CategoryAnswer.exists?(player: bot_player, category_instance: ci)

          answers_params[ci.id.to_s] = "#{letter}#{('a'..'z').to_a.sample(3).join} #{ci.name.first(4).downcase}"
        end

        next if answers_params.empty?

        Games::CategoryList.submit_answers(game:, player: bot_player, answers_params:)
        game.reload
      end
    end

    private_class_method :submit_answers
  end
end
