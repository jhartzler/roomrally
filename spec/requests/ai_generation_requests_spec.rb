require "rails_helper"

RSpec.describe "AiGenerationRequests", type: :request do
  let(:user) { create(:user) }
  let(:pack) { create(:prompt_pack, user: user) }

  before { sign_in(user) }

  describe "POST /ai_generation_requests" do
    let(:valid_params) do
      { pack_type: "prompt_pack", pack_id: pack.id, user_theme: "90s movies" }
    end

    before do
      allow(AiGenerationJob).to receive(:perform_later)
    end

    it "creates a request record" do
      expect {
        post ai_generation_requests_path, params: valid_params
      }.to change(AiGenerationRequest, :count).by(1)
    end

    it "enqueues the job" do
      post ai_generation_requests_path, params: valid_params
      expect(AiGenerationJob).to have_received(:perform_later)
    end

    it "returns a turbo stream response" do
      post ai_generation_requests_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.content_type).to include("turbo-stream")
    end

    context "when user is at the rate limit" do
      before do
        10.times { create(:ai_generation_request, user: user, counts_against_limit: true, created_at: 1.hour.ago) }
      end

      it "does not create a request" do
        expect {
          post ai_generation_requests_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.not_to change(AiGenerationRequest, :count)
      end

      it "returns a rate limit turbo stream response" do
        post ai_generation_requests_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include("rate-limit")
      end
    end

    context "when user is not logged in" do
      before { sign_out }

      it "redirects to login" do
        post ai_generation_requests_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /ai_generation_requests/:id/commit" do
    let(:items) { 10.times.map { |i| { "body" => "Prompt #{i}" } } }
    let(:ai_request) do
      create(:ai_generation_request,
        user: user,
        pack_type: "prompt_pack",
        pack_id: pack.id,
        status: :succeeded,
        parsed_items: items)
    end

    context "append mode" do
      it "appends selected items to the pack" do
        expect {
          patch commit_ai_generation_request_path(ai_request),
            params: { selected_indices: [ "0", "1" ], mode: "append" }
        }.to change { pack.reload.prompts.count }.by(2)
      end

      it "redirects to the pack edit page" do
        patch commit_ai_generation_request_path(ai_request),
          params: { selected_indices: [ "0" ], mode: "append" }
        expect(response).to redirect_to(edit_prompt_pack_path(pack))
      end
    end

    context "replace mode" do
      before { create(:prompt, prompt_pack: pack) }

      it "replaces all existing items with selected items" do
        patch commit_ai_generation_request_path(ai_request),
          params: { selected_indices: [ "0", "1", "2" ], mode: "replace" }
        expect(pack.reload.prompts.count).to eq(3)
      end
    end
  end
end
