# app/services/games/write_and_vote.rb
module Games
  module WriteAndVote
    def self.game_started(room)
      Rails.logger.info "Games::WriteAndVote.game_started invoked for room #{room.code}"
      # Force reload

      # Idempotency check: if the room already has a current game, don't start another one.
      return if room.current_game.present?

      players = room.players.to_a
      num_players = players.size

      # Select N random master prompts
      master_prompts = Prompt.order("RANDOM()").limit(num_players)

      if master_prompts.count < num_players
        raise "Not enough master prompts to start the game."
      end

      # Create the game session
      game = WriteAndVoteGame.create!
      room.update!(current_game: game)

      # Create PromptInstances associated with the game
      prompt_instances = master_prompts.map do |master_prompt|
        PromptInstance.new(write_and_vote_game: game, prompt: master_prompt, body: master_prompt.body)
      end
      prompt_instances.each(&:save!)

      # Assign PromptInstances to players
      players.each_with_index do |player, i|
        prompt_instance1 = prompt_instances[i]
        prompt_instance2 = prompt_instances[(i + 1) % num_players]

        Response.create!(player:, prompt_instance: prompt_instance1)
        Response.create!(player:, prompt_instance: prompt_instance2)
      end

      # Broadcast to all players
      room.players.each do |player|
        Rails.logger.info "Broadcasting to player #{player.id} (hand_screen)"
        Turbo::StreamsChannel.broadcast_update_to(
          player,
          target: "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
    end

    def self.process_vote(game, vote)
      # Get the current prompt instance being voted on
      current_prompt = game.current_round_prompts.order(:id)[game.current_prompt_index]

      # Count votes for this prompt's responses
      total_votes = Vote.where(response: current_prompt.responses).count
      players_count = game.room.players.count

      # If all players have voted (or enough votes cast)
      if total_votes >= players_count
        # Check if we have more prompts to vote on in this round
        if game.current_prompt_index < game.current_round_prompts.count - 1
          game.next_voting_round!
        else
          # End of voting for this game round
          if game.round < 2
            game.start_next_game_round!
            assign_prompts_for_round(game, 2)
            return
          else
            game.finish_game!
          end
        end
      end

      # Broadcast update (to show votes or next screen)
      game.room.players.each do |player|
        Rails.logger.info "Broadcasting to player #{player.id} (hand_screen)"
        Turbo::StreamsChannel.broadcast_update_to(
          player,
          target: "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room: game.room.reload, player: }
        )
      end
    end
    def self.check_all_responses_submitted(game)
      # Check if all responses for this game have been submitted
      # We can check if any response body is nil or empty
      # Note: We need to check all responses linked to this game's prompt instances for the current round

      all_submitted = !Response.joins(:prompt_instance)
                               .where(prompt_instances: { write_and_vote_game_id: game.id, round: game.round })
                               .where(body: [ nil, "" ])
                               .exists?

      if all_submitted
        game.start_voting!

        # Broadcast update to show voting screen
        game.room.players.each do |player|
          Turbo::StreamsChannel.broadcast_update_to(
            player,
            target: "hand_screen",
            partial: "rooms/hand_screen_content",
            locals: { room: game.room.reload, player: }
          )
        end
      end
      game
    end


    def self.assign_prompts_for_round(game, round_number)
      room = game.room
      players = room.players.to_a
      num_players = players.size

      # Select N random master prompts
      master_prompts = Prompt.order("RANDOM()").limit(num_players)

      if master_prompts.count < num_players
        raise "Not enough master prompts to start round #{round_number}."
      end

      # Create PromptInstances associated with the game
      prompt_instances = master_prompts.map do |master_prompt|
        PromptInstance.new(write_and_vote_game: game, prompt: master_prompt, body: master_prompt.body, round: round_number)
      end
      prompt_instances.each(&:save!)

      # Assign PromptInstances to players
      players.each_with_index do |player, i|
        prompt_instance1 = prompt_instances[i]
        prompt_instance2 = prompt_instances[(i + 1) % num_players]

        Response.create!(player:, prompt_instance: prompt_instance1)
        Response.create!(player:, prompt_instance: prompt_instance2)
      end

      # Broadcast to all players
      room.players.each do |player|
        Rails.logger.info "Broadcasting to player #{player.id} (hand_screen)"
        Turbo::StreamsChannel.broadcast_update_to(
          player,
          target: "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
    end
  end
end
