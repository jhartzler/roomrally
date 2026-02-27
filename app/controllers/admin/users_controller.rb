class Admin::UsersController < Admin::BaseController
  def index
    @users = User.includes(:ai_generation_requests, :rooms, :prompt_packs, :trivia_packs, :category_packs)
                 .order(created_at: :desc)
  end

  def show
    @user = User.includes(:ai_generation_requests, :rooms, :prompt_packs, :trivia_packs, :category_packs)
                .find(params[:id])
  end

  def reset_ai_limit
    @user = User.find(params[:id])
    @user.ai_generation_requests
         .where(counts_against_limit: true)
         .where("created_at > ?", User::AI_WINDOW_HOURS.hours.ago)
         .update_all(counts_against_limit: false)
    redirect_to admin_user_path(@user), notice: "AI limit reset for #{@user.name}."
  end
end
