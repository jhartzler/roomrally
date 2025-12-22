class PromptPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prompt_pack, only: %i[edit update destroy]

  def index
    @prompt_packs = current_user.prompt_packs.order(created_at: :desc)
    @system_packs = PromptPack.global.order(name: :asc)
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

  def set_prompt_pack
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
