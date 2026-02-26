class AiGenerationRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_request_for_commit, only: [:commit]

  def create
    if current_user.ai_requests_remaining <= 0
      render turbo_stream: turbo_stream.update("ai-panel-status",
        partial: "ai_generation_requests/rate_limit",
        locals: { user: current_user }
      ) and return
    end

    @ai_request = AiGenerationRequest.create!(
      user: current_user,
      pack_type: params[:pack_type],
      pack_id: params[:pack_id],
      user_theme: params[:user_theme]
    )

    AiGenerationJob.perform_later(@ai_request.id)

    render turbo_stream: turbo_stream.update("ai-panel-status",
      partial: "ai_generation_requests/processing",
      locals: { request: @ai_request }
    )
  end

  def commit
    pack = @ai_request.target_pack
    items = @ai_request.items_for_indices(params[:selected_indices])

    case @ai_request.pack_type
    when "prompt_pack"
      pack.prompts.destroy_all if params[:mode] == "replace"
      items.each { |item| pack.prompts.create!(body: item["body"]) }
      redirect_to edit_prompt_pack_path(pack), notice: "#{items.length} prompts added!"
    when "trivia_pack"
      pack.trivia_questions.destroy_all if params[:mode] == "replace"
      items.each do |item|
        pack.trivia_questions.create!(body: item["body"], options: item["options"], correct_answers: item["correct_answers"])
      end
      redirect_to edit_trivia_pack_path(pack), notice: "#{items.length} questions added!"
    when "category_pack"
      pack.categories.destroy_all if params[:mode] == "replace"
      items.each { |item| pack.categories.create!(name: item["name"]) }
      redirect_to edit_category_pack_path(pack), notice: "#{items.length} categories added!"
    end
  end

  private

  def set_request_for_commit
    @ai_request = current_user.ai_generation_requests.find(params[:id])
  end
end
