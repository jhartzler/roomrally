require 'rails_helper'

RSpec.describe ContactMailer, type: :mailer do
  describe '#contact_email' do
    let(:contact_params) do
      {
        name: "Test User",
        email: "testuser@example.com",
        subject: "Bug Report",
        message: "I found a bug in the voting system."
      }
    end

    let(:mail) { described_class.contact_email(**contact_params) }

    it "renders the headers" do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        expect(mail.subject).to eq("[RoomRally Contact] Bug Report")
        expect(mail.to).to eq([ "support@roomrally.app" ])
        expect(mail.from).to eq([ "noreply@roomrally.app" ])
        expect(mail.reply_to).to eq([ "testuser@example.com" ])
      end
    end

    it "renders the body" do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        expect(mail.body.encoded).to include("Test User")
        expect(mail.body.encoded).to include("testuser@example.com")
        expect(mail.body.encoded).to include("Bug Report")
        expect(mail.body.encoded).to include("I found a bug in the voting system")
      end
    end

    it "includes both HTML and text parts" do
      expect(mail.parts.map(&:content_type)).to include(
        a_string_matching(/text\/plain/),
        a_string_matching(/text\/html/)
      )
    end
  end
end
