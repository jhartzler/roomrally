# app/services/games/write_and_vote.rb
module Games
  module WriteAndVote
    def self.game_started(room)
      Rails.logger.info "Games::WriteAndVote.game_started invoked for room #{room.code}"

      players = room.players.to_a
      num_players = players.size

      # 1. Select N random master prompts
      master_prompts = Prompt.order("RANDOM()").limit(num_players)

      if master_prompts.count < num_players
        raise "Not enough master prompts to start the game."
      end

      # 2. Create PromptInstances from master prompts
      prompt_instances = master_prompts.map do |master_prompt|
        PromptInstance.new(room:, prompt: master_prompt, body: master_prompt.body)
      end
      prompt_instances.each(&:save!)

      # 3. Assign PromptInstances to players
      players.each_with_index do |player, i|
        # Player i gets PromptInstance i and PromptInstance (i + 1) % N
        prompt_instance1 = prompt_instances[i]
        prompt_instance2 = prompt_instances[(i + 1) % num_players]

        Response.create!(player:, prompt_instance: prompt_instance1)
        Response.create!(player:, prompt_instance: prompt_instance2)
      end

      # 4. Broadcast to all players
      room.players.each do |player|
        room.broadcast_replace_to(
          player,
          target: "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
    end
  end
end
