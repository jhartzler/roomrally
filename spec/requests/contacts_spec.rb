require 'rails_helper'

RSpec.describe "Contacts", type: :request do
  describe "GET /contact/new" do
    it "returns http success" do
      get new_contact_path
      expect(response).to have_http_status(:success)
    end

    it "displays the contact form" do
      get new_contact_path
      expect(response.body).to include("Contact Us")
      expect(response.body).to include("Send Message")
    end
  end

  describe "POST /contact" do
    let(:valid_params) do
      {
        contact: {
          name: "Test User",
          email: "test@example.com",
          subject: "Test Subject",
          message: "This is a test message."
        }
      }
    end

    let(:invalid_params) do
      {
        contact: {
          name: "",
          email: "invalid-email",
          subject: "",
          message: ""
        }
      }
    end

    context "with valid parameters" do
      it "redirects to root path with success message" do
        post contact_path, params: valid_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Thanks for reaching out")
      end

      it "enqueues a contact email" do
        expect {
          post contact_path, params: valid_params
        }.to have_enqueued_mail(ContactMailer, :contact_email)
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable entity status" do
        post contact_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "displays validation errors" do
        post contact_path, params: invalid_params
        expect(response.body).to include("Please fix the following errors")
      end

      it "does not enqueue a contact email" do
        expect {
          post contact_path, params: invalid_params
        }.not_to have_enqueued_mail(ContactMailer, :contact_email)
      end
    end
  end
end
