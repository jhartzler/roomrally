class PromptPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owned_prompt_pack, only: %i[edit update destroy]

  def index
    @prompt_packs = current_user.prompt_packs.includes(:prompts).order(created_at: :desc)
    @system_packs = PromptPack.global.includes(:prompts).order(name: :asc)
  end

  def show
    @prompt_pack = PromptPack.where(id: params[:id])
                             .where("user_id = ? OR user_id IS NULL", current_user.id)
                             .first!
  end

  def new
    @prompt_pack = current_user.prompt_packs.new(game_type: "Write And Vote")
    @prompt_pack.prompts.build
  end

  def create
    @prompt_pack = current_user.prompt_packs.new(prompt_pack_params)

    if @prompt_pack.save
      redirect_to prompt_packs_path, notice: "Prompt pack created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @prompt_pack.update(prompt_pack_params)
      redirect_to prompt_packs_path, notice: "Prompt pack updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prompt_pack.destroy
    redirect_to prompt_packs_path, notice: "Prompt pack deleted."
  end

  private

  def set_owned_prompt_pack
    @prompt_pack = current_user.prompt_packs.find(params[:id])
  end

  def prompt_pack_params
    params.require(:prompt_pack).permit(
      :name,
      :game_type,
      :status,
      prompts_attributes: [ :id, :body, :_destroy ]
    )
  end
end
