class HuntPacksController < ApplicationController
  include PackReturnNavigation
  include StudioLayout

  before_action :authenticate_user!
  before_action :set_owned_hunt_pack, only: %i[show edit update destroy]

  def index
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs")
    @hunt_packs = current_user.hunt_packs.includes(:hunt_prompts).recent
    @system_packs = HuntPack.global.includes(:hunt_prompts).alphabetical
  end

  def show
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb(@hunt_pack.name)
  end

  def new
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb("New Pack")
    @hunt_pack = current_user.hunt_packs.new(game_type: "Scavenger Hunt")
    @hunt_pack.hunt_prompts.build
    @return_to = params[:return_to]
  end

  def create
    @hunt_pack = current_user.hunt_packs.new(hunt_pack_params)

    if @hunt_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @hunt_pack.id),
                    notice: "Hunt pack created. Returning to your game."
      else
        redirect_to edit_hunt_pack_path(@hunt_pack), notice: "Hunt pack created."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb(@hunt_pack.name)
    @return_to = params[:return_to]
  end

  def update
    if @hunt_pack.update(hunt_pack_params)
      redirect_to hunt_packs_path, notice: "Hunt pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @hunt_pack.destroy
    redirect_to hunt_packs_path, notice: "Hunt pack deleted."
  end

  private

  def set_owned_hunt_pack
    @hunt_pack = current_user.hunt_packs.find(params[:id])
  end

  def hunt_pack_params
    params.require(:hunt_pack).permit(
      :name,
      :game_type,
      :status,
      hunt_prompts_attributes: %i[id body weight position _destroy]
    )
  end
end
