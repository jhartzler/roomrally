module Games
  module WriteAndVote
    MAX_ROUNDS = 2

    def self.game_started(room:, timer_enabled: false, timer_increment: 60, question_count: nil)
      Rails.logger.info({ event: "game_started", room_code: room.code, player_count: room.players.count, timer_enabled:, timer_increment: })



      return if room.current_game.present?

      # Create the game first
      pack = room.prompt_pack || PromptPack.default
      game = WriteAndVoteGame.create!(
        prompt_pack: pack,
        timer_enabled:,
        timer_increment:
      )
      room.update!(current_game: game)

      assign_prompts_for_round(game:, round_number: 1)
      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
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
        players_count = game.room.players.count
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
      players = room.players.to_a
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
  end
end
