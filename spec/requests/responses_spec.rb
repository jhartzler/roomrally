require 'rails_helper'

RSpec.describe "Responses", type: :request do
  describe "PATCH /responses/:id" do
    let(:room) { FactoryBot.create(:room) }
    let(:player) { FactoryBot.create(:player, room:) }
    let(:prompt_instance) { FactoryBot.create(:prompt_instance, room:) }
    let!(:response) { FactoryBot.create(:response, player:, prompt_instance:, body: nil) }

    it "updates the response and broadcasts a turbo stream" do
      # 1. Expect the broadcast to happen
      # We need to use a spy/mock to verify the broadcast is called.
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with(
          [room, player], # The streamable
          target: "prompt-instance-#{prompt_instance.id}",
          partial: "responses/submission_success",
          locals: { response: }
        )

      # 2. Perform the action
      patch response_url(response), params: {
        response: {
          body: "This is a test answer."
        }
      }

      # 3. Assertions
      expect(response.reload.body).to eq("This is a test answer.")
      expect(response.prompt_instance.reload.status).to eq("submitted")
    end
  end
end
