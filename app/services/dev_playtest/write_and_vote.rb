module DevPlaytest
  module WriteAndVote
    def self.start(room:)
      Games::WriteAndVote.game_started(room:, show_instructions: true)
    end

    def self.advance(game:)
      case game.status
      when "instructions"
        Games::WriteAndVote.start_from_instructions(game:)
      end
    end

    def self.bot_act(game:, exclude_player:)
      case game.status
      when "writing"
        submit_responses(game:, exclude_player:)
      when "voting"
        cast_votes(game:, exclude_player:)
      end
    end

    def self.auto_play_step(game:)
      case game.status
      when "instructions"
        Games::WriteAndVote.start_from_instructions(game:)
      when "writing", "voting"
        bot_act(game:, exclude_player: nil)
      end
    end

    def self.progress_label(game:)
      "Round #{game.round} of 2"
    end

    def self.dashboard_actions(status)
      case status
      when "lobby"
        [ { label: "Start Game", action: :start, style: :primary } ]
      when "instructions"
        [ { label: "Skip Instructions", action: :advance, style: :primary } ]
      when "writing"
        [ { label: "Bots: Submit Responses", action: :bot_act, style: :bot } ]
      when "voting"
        [ { label: "Bots: Cast Votes", action: :bot_act, style: :bot } ]
      when "finished"
        []
      else
        []
      end
    end

    # -- Bot behaviors (private) --

    def self.submit_responses(game:, exclude_player:)
      blank_responses = game.responses
                           .joins(:prompt_instance)
                           .where(prompt_instances: { round: game.round })
                           .where(body: [ nil, "" ])

      blank_responses = blank_responses.where.not(player: exclude_player) if exclude_player

      blank_responses.each do |response|
        response.update!(body: "Bot response #{rand(1000)}", status: "submitted")
        response.prompt_instance.update!(status: "submitted")
      end

      Games::WriteAndVote.check_all_responses_submitted(game:)
    end

    def self.cast_votes(game:, exclude_player:)
      current_prompt = game.current_round_prompts.order(:id)[game.current_prompt_index]
      return unless current_prompt

      bot_players = game.room.players
      bot_players = bot_players.where.not(id: exclude_player.id) if exclude_player

      bot_players.each do |bot_player|
        already_voted = Vote.joins(:response)
                            .where(player: bot_player, responses: { prompt_instance_id: current_prompt.id })
                            .exists?
        next if already_voted

        eligible_responses = current_prompt.responses.where.not(player: bot_player)
        chosen_response = eligible_responses.sample
        next unless chosen_response

        vote = Vote.create!(player: bot_player, response: chosen_response)
        Games::WriteAndVote.process_vote(game:, vote:)
        game.reload
      end
    end

    private_class_method :submit_responses, :cast_votes
  end
end
