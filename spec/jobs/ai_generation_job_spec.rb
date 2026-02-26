require "rails_helper"

RSpec.describe AiGenerationJob, type: :job do
  let(:user) { create(:user) }
  let(:pack) { create(:prompt_pack, user:) }
  let(:request) do
    create(:ai_generation_request,
      user:,
      pack_type: "prompt_pack",
      pack_id: pack.id,
      user_theme: "90s movies",
      status: :pending)
  end

  let(:valid_content) { { "items" => 10.times.map { |i| { "body" => "Prompt #{i}" } } }.to_json }

  let(:raw_response_json) do
    {
      "id" => "chatcmpl-test",
      "model" => "gpt-4.1-mini",
      "choices" => [ { "message" => { "content" => valid_content } } ]
    }.to_json
  end

  before do
    allow(LlmClient).to receive(:generate).and_return(
      { success: true, content: valid_content, raw_response: raw_response_json }
    )
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  describe "on success" do
    it "updates request status to succeeded" do
      described_class.perform_now(request.id)
      expect(request.reload.status).to eq("succeeded")
    end

    it "stores parsed_items on the request" do
      described_class.perform_now(request.id)
      expect(request.reload.parsed_items.length).to eq(10)
    end

    it "stores the raw_response" do
      described_class.perform_now(request.id)
      expect(request.reload.raw_response).to be_present
    end

    it "sets counts_against_limit to true" do
      described_class.perform_now(request.id)
      expect(request.reload.counts_against_limit).to be true
    end

    it "broadcasts a review turbo stream" do
      described_class.perform_now(request.id)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).once
    end
  end

  describe "on parse failure" do
    before do
      allow(LlmClient).to receive(:generate).and_return(
        { success: true, content: '{"items":[]}', raw_response: raw_response_json }
      )
    end

    it "updates request status to failed" do
      described_class.perform_now(request.id)
      expect(request.reload.status).to eq("failed")
    end

    it "sets counts_against_limit to false when within grace limit" do
      described_class.perform_now(request.id)
      expect(request.reload.counts_against_limit).to be false
    end

    it "sets counts_against_limit to true when grace limit exhausted" do # rubocop:disable RSpec/ExampleLength
      3.times do
        create(:ai_generation_request,
          user:, status: :failed,
          counts_against_limit: false,
          created_at: 1.hour.ago)
      end
      described_class.perform_now(request.id)
      expect(request.reload.counts_against_limit).to be true
    end
  end

  describe "on LLM API failure" do
    before do
      allow(LlmClient).to receive(:generate).and_return(
        { success: false, error: "Timeout", raw_response: nil }
      )
    end

    it "updates request status to failed" do
      described_class.perform_now(request.id)
      expect(request.reload.status).to eq("failed")
    end

    it "stores the error message" do
      described_class.perform_now(request.id)
      expect(request.reload.error_message).to eq("Timeout")
    end
  end
end
