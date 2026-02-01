class CustomizeController < ApplicationController
  before_action :authenticate_user!

  def index
    @prompt_packs_count = current_user.prompt_packs.count
    @trivia_packs_count = current_user.trivia_packs.count
  end
end
