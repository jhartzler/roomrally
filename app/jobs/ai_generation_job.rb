class AiGenerationJob < ApplicationJob
  queue_as :default

  def perform(ai_generation_request_id)
    request = AiGenerationRequest.find(ai_generation_request_id)
    request.update!(status: :processing)

    system_prompt = AiContent::Prompts.for(request.pack_type)
    user_prompt = "<user_theme>#{request.user_theme}</user_theme>"
    result = LlmClient.generate(system_prompt:, user_prompt:)

    if result[:success]
      request.update!(raw_response: result[:raw_response])
      parsed = AiContent::Parser.parse(result[:content], request.pack_type)

      if parsed
        request.update!(status: :succeeded, counts_against_limit: true, parsed_items: parsed)
        broadcast_result(request, "ai_generation_requests/review")
      else
        fail_request(request, "Response did not match expected format", result[:raw_response])
      end
    else
      fail_request(request, result[:error], result[:raw_response])
    end
  end

  private

  def fail_request(request, error_message, raw_response)
    grace_used = AiGenerationRequest
      .where(user: request.user, status: :failed, counts_against_limit: false)
      .where("created_at > ?", User::AI_WINDOW_HOURS.hours.ago)
      .count

    request.update!(
      status: :failed,
      error_message: error_message,
      raw_response: raw_response,
      counts_against_limit: grace_used >= User::AI_GRACE_FAILURE_LIMIT
    )
    broadcast_result(request, "ai_generation_requests/error")
  end

  def broadcast_result(request, partial)
    Turbo::StreamsChannel.broadcast_update_to(
      request,
      target: "ai-panel-status",
      partial: partial,
      locals: { request: }
    )
  end
end
