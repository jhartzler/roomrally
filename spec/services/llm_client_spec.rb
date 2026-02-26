require "rails_helper"

RSpec.describe LlmClient do
  describe ".generate" do
    let(:system_prompt) { "You are a trivia writer." }
    let(:user_prompt) { "<user_theme>90s movies</user_theme>" }

    context "when the API call succeeds" do
      let(:raw_response) do
        {
          "id" => "chatcmpl-abc123",
          "model" => "gpt-4.1-mini",
          "usage" => { "prompt_tokens" => 100, "completion_tokens" => 200 },
          "choices" => [
            { "message" => { "role" => "assistant", "content" => '{"items":[]}' }, "finish_reason" => "stop" }
          ]
        }
      end

      before do
        client_double = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:chat).and_return(raw_response)
      end

      it "returns success: true with content and raw_response" do
        result = LlmClient.generate(system_prompt:, user_prompt:)
        expect(result[:success]).to be true
        expect(result[:content]).to eq('{"items":[]}')
        expect(result[:raw_response]).to include('"id"')
      end
    end

    context "when the API raises an error" do
      before do
        client_double = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:chat).and_raise(Faraday::TimeoutError)
      end

      it "returns success: false with an error message" do
        result = LlmClient.generate(system_prompt:, user_prompt:)
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
        expect(result[:raw_response]).to be_nil
      end
    end

    context "when the response has no content" do
      let(:raw_response) do
        {
          "choices" => [
            { "message" => { "role" => "assistant", "content" => nil }, "finish_reason" => "stop" }
          ]
        }
      end

      before do
        client_double = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:chat).and_return(raw_response)
      end

      it "returns success: false" do
        result = LlmClient.generate(system_prompt:, user_prompt:)
        expect(result[:success]).to be false
      end
    end
  end
end
