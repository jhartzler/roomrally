class CategoryPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owned_category_pack, only: %i[show edit update destroy]

  def index
    @category_packs = current_user.category_packs.includes(:categories).recent
    @system_packs = CategoryPack.global.includes(:categories).alphabetical
  end

  def show
  end

  def new
    @category_pack = current_user.category_packs.new(game_type: "Category List")
    @category_pack.categories.build
    @return_to = params[:return_to]
  end

  def create
    @category_pack = current_user.category_packs.new(category_pack_params)

    if @category_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @category_pack.id),
                    notice: "Category pack created. Returning to your game."
      else
        redirect_to category_packs_path, notice: "Category pack created successfully."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @return_to = params[:return_to]
  end

  def update
    if @category_pack.update(category_pack_params)
      redirect_to category_packs_path, notice: "Category pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @category_pack.destroy
    redirect_to category_packs_path, notice: "Category pack deleted."
  end

  private

  def set_owned_category_pack
    @category_pack = current_user.category_packs.find(params[:id])
  end

  def category_pack_params
    params.require(:category_pack).permit(
      :name,
      :game_type,
      :status,
      categories_attributes: [ :id, :name, :_destroy ]
    )
  end
end
