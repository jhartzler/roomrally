module Games
  module WriteAndVote
    MAX_ROUNDS = 2

    def self.requires_capacity_check? = true

    def self.game_started(room:, timer_enabled: false, timer_increment: GameTemplate::SETTING_DEFAULTS["timer_increment"], question_count: nil, show_instructions: true, **_extra)
      Rails.logger.info({ event: "game_started", room_code: room.code, player_count: room.players.active_players.count, timer_enabled:, timer_increment:, show_instructions: })

      Analytics.track(
        distinct_id: room.user_id ? "user_#{room.user_id}" : "room_#{room.code}",
        event: "game_started",
        properties: { game_type: room.game_type, room_code: room.code, player_count: room.players.active_players.count, timer_enabled:, show_instructions: }
      )

      return if room.current_game.present?

      # Create the game first
      pack = room.prompt_pack || PromptPack.default
      game = WriteAndVoteGame.create!(
        prompt_pack: pack,
        timer_enabled:,
        timer_increment:,
        show_instructions:
      )
      room.update!(current_game: game)

      # Skip instructions if disabled - assign prompts immediately
      if show_instructions
        GameBroadcaster.broadcast_game_start(room:)
        GameBroadcaster.broadcast_stage(room:)
        GameBroadcaster.broadcast_hand(room:)
      else
        game.start_game!
        assign_prompts_for_round(game:, round_number: 1)
        GameBroadcaster.broadcast_game_start(room:)
        GameBroadcaster.broadcast_stage(room:)
        GameBroadcaster.broadcast_hand(room:)
      end
    end

    def self.start_from_instructions(game:)
      game.start_game!
      assign_prompts_for_round(game:, round_number: 1)
      room = game.room
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    def self.process_vote(game:, vote:)
      game.with_lock do
        current_prompt = game.current_round_prompts.order(:id)[game.current_prompt_index]

        if current_prompt.nil?
          Rails.logger.error({ event: "process_vote_error", error: "current_prompt_nil", game_id: game.id, round: game.round, prompt_index: game.current_prompt_index })
          return game
        end

        Rails.logger.info({ event: "process_vote", game_id: game.id, round: game.round, prompt_index: game.current_prompt_index, vote_id: vote.id })

        total_votes = Vote.where(response: current_prompt.responses).count
        players_count = game.room.players.active_players.count
        # Authors cannot vote on the prompt they responded to
        required_votes = players_count - current_prompt.responses.count

        if total_votes >= required_votes
          # Ensure we haven't already advanced past this prompt index (though logic above re-fetches current_prompt based on index)
          # If concurrent request advanced index, `game.current_prompt_index` would be higher (due to reload).
          # And `current_prompt` would be the NEXT prompt.
          # So we would be checking votes for the NEXT prompt.
          # If that next prompt doesn't have enough votes, we stop.
          # So strictly speaking, `with_lock` protects us.
          advance_game_state!(game:)
        end
      end

      # Broadcasts can happen outside lock to reduce contention
      GameBroadcaster.broadcast_hand(room: game.room)
      GameBroadcaster.broadcast_stage(room: game.room)
    end
    def self.check_all_responses_submitted(game:)
      game.with_lock do
        if game.all_responses_submitted?
          transition_to_voting(game:)
        end
      end
      game
    end

    def self.assign_prompts_for_round(game:, round_number:)
      room = game.room
      players = room.players.active_players.to_a
      num_players = players.size


      used_prompt_ids = PromptInstance.where(write_and_vote_game: game).pluck(:prompt_id)

      # Use the game's pack prompts, or fall back to DEFAULT scoped pool (safety net)
      # NEVER fall back to global Prompt.all because that leaks private user prompts.
      prompt_scope = (game.prompt_pack || PromptPack.default).prompts
      available_prompt_ids = prompt_scope.where.not(id: used_prompt_ids).pluck(:id)
      sampled_ids = available_prompt_ids.sample(num_players)

      if sampled_ids.size < num_players
        raise "Not enough master prompts to start round #{round_number}."
      end

      master_prompts = Prompt.where(id: sampled_ids).to_a.shuffle


      prompt_instances = master_prompts.map do |master_prompt|
        PromptInstance.new(write_and_vote_game: game, prompt: master_prompt, body: master_prompt.body, round: round_number)
      end
      prompt_instances.each(&:save!)


      players.each_with_index do |player, i|
        prompt_instance1 = prompt_instances[i]
        prompt_instance2 = prompt_instances[(i + 1) % num_players]

        Response.create!(player:, prompt_instance: prompt_instance1)
        Response.create!(player:, prompt_instance: prompt_instance2)
      end

      # Schedule Timer
      start_timer_if_enabled(game)
    end

    def self.handle_timeout(game:)
      if game.status == "writing"
        # Find all responses for this round that are empty
        current_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: game.round).pluck(:id)
        missing_responses = Response.where(prompt_instance_id: current_prompt_ids, body: [ nil, "" ])

        if missing_responses.any?
          missing_responses.update_all(body: "Ran out of time!")
        end

        transition_to_voting(game:)
      elsif game.status == "voting"
        # Force advance to next prompt or next round
        advance_game_state!(game:)

        GameBroadcaster.broadcast_hand(room: game.room)
        GameBroadcaster.broadcast_stage(room: game.room)
      end
    end


    def self.advance_game_state!(game:)
      if game.current_prompt_index < game.current_round_prompts.count - 1
        game.next_voting_round!
        start_timer_if_enabled(game, step_number: game.current_prompt_index)
      else
        game.calculate_scores!
        if game.round < MAX_ROUNDS
          game.start_next_game_round!
          assign_prompts_for_round(game:, round_number: game.round)
        else
          game.finish_game!
          Analytics.track(
            distinct_id: game.room.user_id ? "user_#{game.room.user_id}" : "room_#{game.room.code}",
            event: "game_completed",
            properties: { game_type: game.room.game_type, room_code: game.room.code, player_count: game.room.players.active_players.count, duration_seconds: (Time.current - game.created_at).to_i }
          )
          game.room.finish!
        end
      end
    end

    def self.start_timer_if_enabled(game, step_number: nil)
      return unless game.timer_enabled?

      game.start_timer!(game.timer_increment, step_number:)
    end

    def self.transition_to_voting(game:)
      # Mark submitted responses as published (clearing them from moderation queue logically)
      current_prompt_ids = PromptInstance.where(write_and_vote_game: game, round: game.round).select(:id)
      Response.where(prompt_instance_id: current_prompt_ids, status: "submitted").update_all(status: "published")

      game.start_voting!

      start_timer_if_enabled(game, step_number: game.current_prompt_index)

      GameBroadcaster.broadcast_hand(room: game.room)
      GameBroadcaster.broadcast_stage(room: game.room)
      GameBroadcaster.clear_moderation_queue(room: game.room)
    end

    private_class_method :start_timer_if_enabled, :transition_to_voting

    module Playtest
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
end
