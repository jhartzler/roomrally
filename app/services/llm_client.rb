class LlmClient
  def self.generate(system_prompt:, user_prompt:)
    client = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY")
    )
    model = ENV.fetch("OPENAI_MODEL", "gpt-4.1-mini")

    raw = client.chat(
      parameters: {
        model:,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        response_format: { type: "json_object" }
      }
    )

    content = raw.dig("choices", 0, "message", "content")
    usage = raw["usage"]
    Rails.logger.info("LlmClient usage: #{usage.inspect}") if usage

    if content.present?
      { success: true, content:, raw_response: raw.to_json }
    else
      { success: false, error: "No content in response", raw_response: raw.to_json }
    end
  rescue => e
    Rails.logger.error("LlmClient error: #{e.class}: #{e.message}")
    { success: false, error: e.message, raw_response: nil }
  end
end
