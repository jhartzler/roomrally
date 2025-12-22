class PromptPacksController < ApplicationController
  def index
    @prompt_packs = current_user.prompt_packs.order(created_at: :desc)
    # Placeholder for system templates or future usage
    @system_packs = []
  end
end
