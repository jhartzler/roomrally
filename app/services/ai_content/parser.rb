module AiContent
  class Parser
    REQUIRED_COUNT = 10

    def self.parse(json_string, pack_type)
      return nil unless json_string.is_a?(String) && json_string.present?

      data = JSON.parse(json_string)
      items = data["items"]
      return nil unless items.is_a?(Array) && items.length == REQUIRED_COUNT

      case pack_type
      when AiGenerationRequest::PROMPT_PACK_TYPE then parse_prompt_pack(items)
      when AiGenerationRequest::TRIVIA_PACK_TYPE then parse_trivia_pack(items)
      when AiGenerationRequest::CATEGORY_PACK_TYPE then parse_category_pack(items)
      end
    rescue JSON::ParserError
      nil
    end

    def self.parse_prompt_pack(items)
      return nil unless items.all? { |item| item["body"].is_a?(String) && item["body"].present? }
      items
    end

    def self.parse_trivia_pack(items)
      items.each do |item|
        options = item["options"]
        correct = item["correct_answers"]
        return nil unless item["body"].is_a?(String) && item["body"].present?
        return nil unless options.is_a?(Array) && options.length == TriviaQuestion::OPTIONS_COUNT
        return nil unless correct.is_a?(Array) && correct.any?
        return nil unless correct.all? { |c| options.include?(c) }
      end
      items
    end

    def self.parse_category_pack(items)
      return nil unless items.all? { |item| item["name"].is_a?(String) && item["name"].present? }
      items
    end
  end
end
