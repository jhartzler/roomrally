
module Games
  module WriteAndVote
    def self.game_started(room)
      Rails.logger.info({ event: "game_started", room_code: room.code, player_count: room.players.count })



      return if room.current_game.present?

      # Create the game first
      game = WriteAndVoteGame.create!
      room.update!(current_game: game)

      # Delegate prompt assignment and broadcasting to the standard method
      assign_prompts_for_round(game, 1)
    end

    def self.process_vote(game, vote)
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

        if game.current_prompt_index < game.current_round_prompts.count - 1
          game.next_voting_round!
        else

          if game.round < 2
            calculate_scores(game)
            game.start_next_game_round!
            assign_prompts_for_round(game, 2)
            return
          else
            calculate_scores(game)
            game.finish_game!
          end
        end
      end


      Games::Broadcaster.broadcast_hand_screen(room: game.room)
    end
    def self.check_all_responses_submitted(game)
      all_submitted = !Response.joins(:prompt_instance)
                               .where(prompt_instances: { write_and_vote_game_id: game.id, round: game.round })
                               .where(body: [ nil, "" ])
                               .exists?

      if all_submitted
        game.start_voting!


        Games::Broadcaster.broadcast_hand_screen(room: game.room)
      end
      game
    end

    def self.calculate_scores(game)
      game.room.players.each do |player|
        score = Response.joins(:votes, :prompt_instance)
                        .where(player:)
                        .where(prompt_instances: { write_and_vote_game_id: game.id })
                        .count * 500
        player.update!(score:)
      end
    end

    def self.assign_prompts_for_round(game, round_number)
      room = game.room
      players = room.players.to_a
      num_players = players.size


      used_prompt_ids = PromptInstance.where(write_and_vote_game: game).pluck(:prompt_id)
      master_prompts = Prompt.where.not(id: used_prompt_ids).order("RANDOM()").limit(num_players)

      if master_prompts.count < num_players
        raise "Not enough master prompts to start round #{round_number}."
      end


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


      Games::Broadcaster.broadcast_hand_screen(room:)
    end
  end
end
