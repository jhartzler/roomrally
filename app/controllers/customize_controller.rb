class CustomizeController < ApplicationController
  include StudioLayout

  before_action :authenticate_user!

  def index
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs")
    @prompt_packs_count = current_user.prompt_packs.count
    @trivia_packs_count = current_user.trivia_packs.count
    @category_packs_count = current_user.category_packs.count
    @hunt_packs_count = current_user.hunt_packs.count
  end
end
