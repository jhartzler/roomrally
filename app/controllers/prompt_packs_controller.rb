class PromptPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owned_prompt_pack, only: %i[edit update destroy]

  def index
    @prompt_packs = current_user.prompt_packs.includes(:prompts).recent
    @system_packs = PromptPack.global.includes(:prompts).alphabetical
  end

  def show
    @prompt_pack = PromptPack.accessible_by(current_user).find(params[:id])
  end

  def new
    @prompt_pack = current_user.prompt_packs.new(game_type: "Write And Vote")
    @prompt_pack.prompts.build
    @return_to = params[:return_to]
  end

  def create
    @prompt_pack = current_user.prompt_packs.new(prompt_pack_params)

    if @prompt_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @prompt_pack.id),
                    notice: "Prompt pack created. Returning to your game."
      else
        redirect_to prompt_packs_path, notice: "Prompt pack created successfully."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @prompt_pack.update(prompt_pack_params)
      redirect_to prompt_packs_path, notice: "Prompt pack updated successfully."
    else
      render :edit, status: :unprocessable_content
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
