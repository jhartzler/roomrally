module GamesHelper
  def active_prompt_index(player, prompts)
    # Calculate active index: First prompt with blank/pending response or rejected status
    prompts.to_a.find_index do |prompt|
      response = player.responses.find_by(prompt_instance: prompt)
      # If pending, it's open for input. If rejected, it needs revision.
      response&.pending? || response&.rejected?
    end || 0
  end
end
