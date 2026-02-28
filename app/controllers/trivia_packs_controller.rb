class TriviaPacksController < ApplicationController
  include PackReturnNavigation

  before_action :authenticate_user!
  before_action :set_owned_trivia_pack, only: %i[edit update destroy]

  def index
    @trivia_packs = current_user.trivia_packs.includes(:trivia_questions).recent
    @system_packs = TriviaPack.global.includes(:trivia_questions).alphabetical
  end

  def show
    @trivia_pack = TriviaPack.accessible_by(current_user).find(params[:id])
  end

  def new
    @trivia_pack = current_user.trivia_packs.new(game_type: "Speed Trivia")
    @trivia_pack.trivia_questions.build
    @return_to = params[:return_to]
  end

  def create
    @trivia_pack = current_user.trivia_packs.new(trivia_pack_params)

    if @trivia_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @trivia_pack.id),
                    notice: "Trivia pack created. Returning to your game."
      else
        redirect_to edit_trivia_pack_path(@trivia_pack), notice: "Trivia pack created."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @trivia_pack.trivia_questions.build if @trivia_pack.trivia_questions.empty?
  end

  def update
    if @trivia_pack.update(trivia_pack_params)
      redirect_to trivia_packs_path, notice: "Trivia pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @trivia_pack.destroy
    redirect_to trivia_packs_path, notice: "Trivia pack deleted."
  end

  private

  def set_owned_trivia_pack
    @trivia_pack = current_user.trivia_packs.find(params[:id])
  end

  def trivia_pack_params
    params.require(:trivia_pack).permit(
      :name,
      :game_type,
      :status,
      trivia_questions_attributes: [
        :id,
        :body,
        :position,
        :_destroy,
        :image,
        :remove_image,
        correct_answers: [],
        options: []
      ]
    )
  end
end
