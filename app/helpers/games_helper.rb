module GamesHelper
  def active_prompt_index(player, prompts)
    # Calculate active index: First prompt with blank/pending response or rejected status
    # Reload responses to avoid stale cache issues during rapid submission loops
    fresh_responses = player.responses.reload
    prompts.to_a.find_index do |prompt|
      response = fresh_responses.find { |r| r.prompt_instance_id == prompt.id }
      # If pending, it's open for input. If rejected, it needs revision.
      response&.pending? || response&.rejected?
    end || 0
  end
end
