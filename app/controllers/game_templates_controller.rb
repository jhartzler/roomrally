class GameTemplatesController < ApplicationController
  include StudioLayout

  before_action :authenticate_user!
  before_action :set_game_template, only: %i[edit update destroy]

  def index
    @studio_active_section = :games
    studio_breadcrumb("My Games")
    @game_templates = current_user.game_templates
      .includes(:prompt_pack, :trivia_pack, :category_pack)
      .order(updated_at: :desc)
  end

  def new
    @studio_active_section = :games
    studio_breadcrumb("My Games", game_templates_path)
    studio_breadcrumb("New Game")
    @game_template = current_user.game_templates.new(new_template_params)
    load_packs
  end

  def create
    @game_template = current_user.game_templates.new(game_template_params)

    if @game_template.save
      Analytics.track(
        distinct_id: "user_#{current_user.id}",
        event: "game_template_created",
        properties: { game_type: @game_template.game_type, template_id: @game_template.id }
      )
      redirect_to game_templates_path, notice: "Game saved successfully."
    else
      load_packs
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @studio_active_section = :games
    studio_breadcrumb("My Games", game_templates_path)
    studio_breadcrumb(@game_template.name)
    load_packs
  end

  def update
    if @game_template.update(game_template_params)
      redirect_to game_templates_path, notice: "Game updated successfully."
    else
      load_packs
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @game_template.destroy
    redirect_to game_templates_path, notice: "Game deleted."
  end

  private

  def set_game_template
    @game_template = current_user.game_templates.find(params[:id])
  end

  def new_template_params
    params.fetch(:game_template, {}).permit(
      :name, :game_type, :prompt_pack_id, :trivia_pack_id, :category_pack_id,
      settings: GameTemplate::SETTING_DEFAULTS.keys
    )
  end

  def game_template_params
    params.require(:game_template).permit(
      :name, :game_type, :prompt_pack_id, :trivia_pack_id, :category_pack_id,
      settings: GameTemplate::SETTING_DEFAULTS.keys
    )
  end

  def load_packs
    @prompt_packs = PromptPack.accessible_by(current_user).alphabetical
    @trivia_packs = TriviaPack.accessible_by(current_user).alphabetical
    @category_packs = CategoryPack.accessible_by(current_user).alphabetical
  end
end
