class PollPacksController < ApplicationController
  include PackReturnNavigation
  include StudioLayout

  before_action :authenticate_user!
  before_action :set_owned_poll_pack, only: %i[show edit update destroy]

  def index
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Poll Packs")
    @poll_packs = current_user.poll_packs.includes(:poll_questions)
  end

  def show
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Poll Packs", poll_packs_path)
    studio_breadcrumb(@poll_pack.name)
  end

  def new
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Poll Packs", poll_packs_path)
    studio_breadcrumb("New Pack")
    @poll_pack = current_user.poll_packs.new
    @poll_pack.poll_questions.build
    @return_to = params[:return_to]
  end

  def create
    @poll_pack = current_user.poll_packs.new(poll_pack_params)

    if @poll_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @poll_pack.id),
                    notice: "Poll pack created. Returning to your game."
      else
        redirect_to edit_poll_pack_path(@poll_pack), notice: "Poll pack created."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Poll Packs", poll_packs_path)
    studio_breadcrumb(@poll_pack.name)
    @poll_pack.poll_questions.build if @poll_pack.poll_questions.empty?
  end

  def update
    if @poll_pack.update(poll_pack_params)
      redirect_to poll_packs_path, notice: "Poll pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @poll_pack.destroy
    redirect_to poll_packs_path, notice: "Poll pack deleted."
  end

  private

  def set_owned_poll_pack
    @poll_pack = current_user.poll_packs.find(params[:id])
  end

  def poll_pack_params
    params.require(:poll_pack).permit(
      :name,
      :status,
      poll_questions_attributes: [
        :id,
        :body,
        :position,
        :_destroy,
        options: []
      ]
    )
  end
end
